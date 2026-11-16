"""Download gemma-4-E2B-it.litertlm when the server folder does not have it."""

from __future__ import annotations

import re
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlencode, urljoin, urlparse
from urllib.request import HTTPCookieProcessor, Request, build_opener

from . import config

_CHUNK = 1024 * 1024
_REPORT = 32 * 1024 * 1024


class _FormParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.action = ""
        self.fields: list[tuple[str, str]] = []
        self._capture = False

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = {key: value or "" for key, value in attrs}
        if tag == "form" and not self.action:
            self.action = values.get("action", "")
            self._capture = True
            return
        if self._capture and tag == "input" and values.get("name"):
            self.fields.append((values["name"], values.get("value", "")))

    def handle_endtag(self, tag: str) -> None:
        if tag == "form":
            self._capture = False


def ensure_gemma_model() -> Path:
    path = config.MODEL_PATH
    if path.is_file() and path.stat().st_size >= config.MODEL_MIN_BYTES:
        return path
    url = config.MODEL_URL
    if not url:
        raise FileNotFoundError(
            f"{path.name} is missing and AURA_MODEL_URL is empty"
        )
    print(f"[model] {path.name} is missing. downloading", flush=True)
    _download(url, path)
    if not path.is_file() or path.stat().st_size < config.MODEL_MIN_BYTES:
        raise FileNotFoundError(f"downloaded model is incomplete: {path}")
    print(f"[model] saved {path} ({path.stat().st_size} bytes)", flush=True)
    return path


def _download(url: str, dest: Path, hops: int = 0) -> None:
    if hops > 3:
        raise RuntimeError("model host did not return the file")
    dest.parent.mkdir(parents=True, exist_ok=True)
    partial = dest.with_name(dest.name + ".part")
    opener = build_opener(HTTPCookieProcessor())
    request = Request(url, headers={"User-Agent": "LuckyStarServer/1.0"})
    with opener.open(request, timeout=120) as response:
        info = response.headers
        content_type = (info.get("Content-Type") or "").split(";", 1)[0].strip().lower()
        first = response.read(_CHUNK)
        if _is_html(content_type, first):
            page = first + response.read()
            follow = _confirm_url(page.decode("utf-8", "replace"), response.geturl())
            if follow is None or follow == url:
                raise RuntimeError("model host returned a page instead of the file")
            print("[model] confirming download", flush=True)
            _download(follow, dest, hops + 1)
            return
        total = int(info.get("Content-Length") or 0)
        got = 0
        next_report = _REPORT
        with partial.open("wb") as handle:
            pending = first
            while pending:
                handle.write(pending)
                got += len(pending)
                if got >= next_report:
                    _report(got, total)
                    next_report = got + _REPORT
                pending = response.read(_CHUNK)
    if partial.stat().st_size < config.MODEL_MIN_BYTES:
        partial.unlink(missing_ok=True)
        raise RuntimeError(
            f"download stopped at {got} bytes. the file must be at least "
            f"{config.MODEL_MIN_BYTES} bytes"
        )
    partial.replace(dest)


def _is_html(content_type: str, first: bytes) -> bool:
    if content_type.startswith("text/html"):
        return True
    sample = first.lstrip().lower()
    return sample.startswith(b"<!doctype html") or sample.startswith(b"<html")


def _confirm_url(page: str, current: str) -> str | None:
    parser = _FormParser()
    parser.feed(page)
    if parser.action and parser.fields:
        action = urljoin(current, parser.action)
        query = urlencode(parser.fields)
        join = "&" if urlparse(action).query else "?"
        return f"{action}{join}{query}"
    match = re.search(r'href="([^"]*confirm=[^"]+)"', page)
    if match:
        return urljoin(current, match.group(1).replace("&amp;", "&"))
    return None


def _report(got: int, total: int) -> None:
    if total:
        print(f"[model] {got}/{total} bytes", flush=True)
        return
    print(f"[model] {got} bytes", flush=True)
