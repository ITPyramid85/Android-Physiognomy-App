"""Aura analysis server.

Run from the server directory:

    pip install -r requirements.txt
    python -m uvicorn app.main:app --host 0.0.0.0 --port 8787

gemma-4-E2B-it.litertlm is loaded in-process.
If that file is not in the server folder, it is downloaded before startup.
Face and palm measurements also run here. The app only uploads a photo
or a chat turn and reads the token stream.
"""

from __future__ import annotations

import asyncio
import json
import threading
from contextlib import asynccontextmanager

from fastapi import FastAPI, File, Form, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

from . import config, gemma_runtime, prompts, vision


class ChatTurn(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    locale: str = "ko"
    analysis_type: str = "face"
    context_summary: str = ""
    features: dict = Field(default_factory=dict)
    history: list[ChatTurn] = Field(default_factory=list)
    message: str


@asynccontextmanager
async def lifespan(_app: FastAPI):
    await asyncio.to_thread(_load_models)
    yield
    gemma_runtime.close()


def _load_models() -> None:
    vision.load()
    gemma_runtime.load()


app = FastAPI(title="Aura Server", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health() -> dict:
    return {
        "ok": vision.ready and gemma_runtime.ready,
        "model": config.MODEL_PATH.name,
        "backend": gemma_runtime.backend,
        "vision_ready": vision.ready,
        "model_ready": gemma_runtime.ready,
        "error": gemma_runtime.error or vision.error,
    }


@app.post("/v1/analyze")
async def analyze(
    request: Request,
    image: UploadFile = File(...),
    kind: str = Form(...),
    locale: str = Form("ko"),
):
    """kind 는 face(얼굴) 또는 hand(손). 진행률은 progress 이벤트로 0–100 을 보낸다."""
    payload = await image.read()
    return _stream(request, lambda cancel: _reading_job(kind, payload, locale, cancel))


@app.post("/v1/face/analyze")
async def analyze_face(
    request: Request,
    image: UploadFile = File(...),
    locale: str = Form("ko"),
):
    payload = await image.read()
    return _stream(request, lambda cancel: _reading_job("face", payload, locale, cancel))


@app.post("/v1/palm/analyze")
async def analyze_palm(
    request: Request,
    image: UploadFile = File(...),
    locale: str = Form("ko"),
):
    payload = await image.read()
    return _stream(request, lambda cancel: _reading_job("hand", payload, locale, cancel))


@app.post("/v1/chat")
async def chat(request: Request, body: ChatRequest):
    history = [{"role": turn.role, "content": turn.content} for turn in body.history]
    return _stream(request, lambda cancel: _chat_job(body, history, cancel))


def _normalize_kind(kind: str) -> str:
    value = kind.strip().lower()
    if value in ("face", "얼굴"):
        return "face"
    if value in ("hand", "palm", "손"):
        return "hand"
    raise vision.VisionError("bad_request", "kind must be face or hand")


def _reading_job(kind: str, payload: bytes, locale: str, cancel: threading.Event):
    kind = _normalize_kind(kind)
    yield "progress", {"percent": 8, "stage": "received"}
    if cancel.is_set():
        return
    yield "progress", {"percent": 18, "stage": "detect"}
    if kind == "hand":
        meta = vision.analyze_palm(payload)
    else:
        meta = vision.analyze_face(payload)
    if cancel.is_set():
        return
    yield "progress", {"percent": 34, "stage": "measure"}
    yield "meta", meta
    if kind == "hand":
        system, user = prompts.palm_prompts(meta["features"], meta["is_left_hand"], locale)
        yield "progress", {"percent": 42, "stage": "read"}
        yield from _tokens(system, user, None, cancel, target=2400, max_output_tokens=4096)
        return
    system, user = prompts.face_prompts(meta["features"], locale)
    yield "progress", {"percent": 42, "stage": "read"}
    yield from _tokens(system, user, None, cancel)


def _chat_job(body: ChatRequest, history: list[dict], cancel: threading.Event):
    text = body.message.strip()
    if not text:
        raise vision.VisionError("bad_request", "message is empty")
    system = prompts.consultation_system(
        body.locale,
        body.analysis_type,
        body.context_summary,
        body.features,
    )
    yield from _tokens(system, text, history, cancel)


def _tokens(
    system: str,
    user: str,
    history: list[dict] | None,
    cancel: threading.Event,
    target: int = 700,
    max_output_tokens: int | None = None,
):
    produced = 0
    last_percent = 42
    for token in gemma_runtime.generate(
        system, user, history, cancel, max_output_tokens=max_output_tokens,
    ):
        if cancel.is_set():
            break
        produced += len(token)
        percent = min(96, 42 + int(54 * produced / target))
        if percent > last_percent:
            last_percent = percent
            yield "progress", {"percent": percent, "stage": "read"}
        yield "token", {"text": token}
    if not cancel.is_set():
        yield "progress", {"percent": 100, "stage": "done"}
        yield "done", {"percent": 100}


def _stream(request: Request, worker):
    return StreamingResponse(
        _events(request, worker),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


async def _events(request: Request, worker):
    loop = asyncio.get_running_loop()
    queue: asyncio.Queue = asyncio.Queue()
    cancel = threading.Event()

    def run() -> None:
        try:
            for kind, payload in worker(cancel):
                if cancel.is_set():
                    break
                asyncio.run_coroutine_threadsafe(queue.put((kind, payload)), loop).result()
        except vision.VisionError as exc:
            asyncio.run_coroutine_threadsafe(
                queue.put(("error", {"code": exc.code, "message": str(exc)})),
                loop,
            ).result()
        except Exception as exc:  # noqa: BLE001 - report to the client
            asyncio.run_coroutine_threadsafe(
                queue.put(("error", {"code": "model", "message": str(exc)})),
                loop,
            ).result()
        finally:
            asyncio.run_coroutine_threadsafe(queue.put(None), loop).result()

    threading.Thread(target=run, daemon=True).start()
    while True:
        if await request.is_disconnected():
            cancel.set()
            break
        item = await queue.get()
        if item is None:
            break
        kind, payload = item
        yield _sse(kind, payload)
        if kind in ("error", "done"):
            break


def _sse(event: str, payload: dict) -> str:
    data = json.dumps(payload, ensure_ascii=False)
    return f"event: {event}\ndata: {data}\n\n"
