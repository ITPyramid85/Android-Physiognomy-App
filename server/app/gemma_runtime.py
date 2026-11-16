"""Gemma 4 E2B via LiteRT-LM. One generation at a time."""

from __future__ import annotations

import inspect
import threading
from collections.abc import Iterator

from . import config
from .model_fetch import ensure_gemma_model

_engine = None
backend = "cpu"
ready = False
error: str | None = None
_lock = threading.Lock()


def load(names: tuple[str, ...] | None = None) -> None:
    global _engine, backend, ready, error
    try:
        ensure_gemma_model()
    except Exception as exc:  # noqa: BLE001 - surfaced on /health
        ready = False
        error = str(exc)
        raise

    import litert_lm

    if hasattr(litert_lm, "set_min_log_severity") and hasattr(litert_lm, "LogSeverity"):
        litert_lm.set_min_log_severity(litert_lm.LogSeverity.ERROR)

    config.CACHE_DIR.mkdir(parents=True, exist_ok=True)
    failures: list[str] = []
    for name in names or config.GEMMA_BACKENDS:
        backend_factory = getattr(litert_lm.Backend, name, None)
        if backend_factory is None:
            continue
        try:
            kwargs = _accepted(
                litert_lm.Engine,
                {"backend": backend_factory(), "cache_dir": str(config.CACHE_DIR)},
            )
            _engine = litert_lm.Engine(str(config.MODEL_PATH), **kwargs)
            backend = name.lower()
            ready = True
            error = None
            return
        except Exception as exc:  # noqa: BLE001 - try the next backend
            failures.append(f"{name}: {exc}")
            _engine = None
    ready = False
    error = "; ".join(failures) or "could not load Gemma"
    raise RuntimeError(error)


def close() -> None:
    global _engine, ready
    engine = _engine
    _engine = None
    ready = False
    if engine is None:
        return
    closer = getattr(engine, "close", None)
    if callable(closer):
        closer()


def generate(
    system: str,
    user: str,
    history: list[dict] | None = None,
    cancel: threading.Event | None = None,
    max_output_tokens: int | None = None,
) -> Iterator[str]:
    if not ready or _engine is None:
        raise RuntimeError(error or "Gemma is not loaded")

    with _lock:
        produced = 0
        try:
            for text in _stream(system, user, history or [], cancel, max_output_tokens):
                produced += 1
                yield text
            return
        except Exception:  # noqa: BLE001 - a broken GPU backend retries on CPU
            cancelled = cancel is not None and cancel.is_set()
            if produced or cancelled or backend == "cpu":
                raise
        load(("CPU",))
        yield from _stream(system, user, history or [], cancel, max_output_tokens)


def _stream(
    system: str,
    user: str,
    history: list[dict],
    cancel: threading.Event | None,
    max_output_tokens: int | None = None,
) -> Iterator[str]:
    import litert_lm

    kwargs = _accepted(
        _engine.create_conversation,
        {
            "messages": _preface(litert_lm, system, history),
            "sampler_config": _sampler(litert_lm),
            "thinking_config": _thinking_off(litert_lm),
            "max_output_tokens": max_output_tokens or config.MAX_OUTPUT_TOKENS,
        },
    )
    with _engine.create_conversation(**kwargs) as conversation:
        for chunk in conversation.send_message_async(user):
            if cancel is not None and cancel.is_set():
                break
            text = _chunk_text(chunk)
            if text:
                yield text


def _preface(litert_lm, system: str, history: list[dict]) -> list:
    messages = [_message(litert_lm, "system", system)]
    for turn in history[-config.CHAT_HISTORY_TURNS :]:
        role = str(turn.get("role") or "user")
        content = str(turn.get("content") or "")
        if not content:
            continue
        if role not in ("user", "assistant", "model"):
            role = "user"
        messages.append(_message(litert_lm, role, content))
    return messages


def _message(litert_lm, role: str, text: str):
    message = litert_lm.Message
    if role == "system" and hasattr(message, "system"):
        return message.system(text)
    if role == "user" and hasattr(message, "user"):
        return message.user(text)
    for name in ("assistant", "model"):
        if role in ("assistant", "model") and hasattr(message, name):
            return getattr(message, name)(text)
    mapped = "model" if role in ("assistant", "model") else role
    return {"role": mapped, "content": text}


def _sampler(litert_lm):
    sampler = getattr(litert_lm, "SamplerConfig", None)
    if sampler is None:
        return None
    return sampler(temperature=config.TEMPERATURE, top_k=config.TOP_K)


def _thinking_off(litert_lm):
    thinking = getattr(litert_lm, "ThinkingConfig", None)
    if thinking is None:
        return None
    try:
        return thinking(enable_thinking=False, thinking_token_budget=0)
    except TypeError:
        return thinking(thinking_token_budget=0)


def _chunk_text(chunk) -> str:
    if isinstance(chunk, str):
        return chunk
    if not isinstance(chunk, dict):
        return ""
    content = chunk.get("content")
    parts: list[str] = []
    if isinstance(content, list):
        for item in content:
            if isinstance(item, str):
                parts.append(item)
            elif isinstance(item, dict) and item.get("type", "text") == "text":
                parts.append(str(item.get("text") or ""))
    elif isinstance(content, dict) and content.get("type", "text") == "text":
        parts.append(str(content.get("text") or ""))
    elif isinstance(content, str):
        parts.append(content)
    return "".join(parts)


def _accepted(fn, kwargs: dict) -> dict:
    cleaned = {key: value for key, value in kwargs.items() if value is not None}
    try:
        signature = inspect.signature(fn)
    except (TypeError, ValueError):
        return cleaned
    if any(param.kind == inspect.Parameter.VAR_KEYWORD for param in signature.parameters.values()):
        return cleaned
    return {key: value for key, value in cleaned.items() if key in signature.parameters}
