"""Face and hand measurement. Landmark models run only on this server."""

from __future__ import annotations

import math
import urllib.request
from io import BytesIO

import numpy as np
from PIL import Image, ImageOps

from . import config

_face = None
_hand = None
ready = False
error: str | None = None


class VisionError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code


def load() -> None:
    global _face, _hand, ready, error
    try:
        _ensure_task(config.FACE_TASK, config.FACE_TASK_URL)
        _ensure_task(config.HAND_TASK, config.HAND_TASK_URL)
        _face = _make_face()
        _hand = _make_hand()
        ready = True
        error = None
    except Exception as exc:  # noqa: BLE001 - surfaced on /health
        ready = False
        error = str(exc)
        raise


def analyze_face(image_bytes: bytes) -> dict:
    _require_ready()
    rgb, width, height = _decode(image_bytes)
    landmarks = _face_landmarks(rgb)
    if landmarks is None:
        raise VisionError("no_face", "no face detected")
    features = _face_features(landmarks)
    return {
        "score": 1.0,
        "frame_width": width,
        "frame_height": height,
        "features": features,
    }


def analyze_palm(image_bytes: bytes) -> dict:
    _require_ready()
    rgb, width, height = _decode(image_bytes)
    landmarks = _hand_landmarks(rgb)
    if landmarks is None:
        raise VisionError("no_palm", "no hand detected")
    features = _palm_features(landmarks)
    # 전면 카메라 JPEG는 좌우가 뒤집혀 있다.
    # 손바닥을 카메라에 향한 왼손은 엄지(4)가 손목(0)보다 왼쪽에 있다.
    is_left = landmarks[4][0] < landmarks[0][0]
    features_out = dict(features)
    return {
        "score": 1.0,
        "frame_width": width,
        "frame_height": height,
        "is_left_hand": is_left,
        "features": features_out,
    }


def _require_ready() -> None:
    if not ready or _face is None or _hand is None:
        raise VisionError("model", error or "vision models are not loaded")


def _ensure_task(path, url: str) -> None:
    if path.is_file() and path.stat().st_size > 0:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    urllib.request.urlretrieve(url, path)


def _make_face():
    import mediapipe as mp
    from mediapipe.tasks import python
    from mediapipe.tasks.python import vision

    options = vision.FaceLandmarkerOptions(
        base_options=python.BaseOptions(model_asset_path=str(config.FACE_TASK)),
        running_mode=vision.RunningMode.IMAGE,
        num_faces=1,
        min_face_detection_confidence=0.5,
    )
    return vision.FaceLandmarker.create_from_options(options), mp


def _make_hand():
    import mediapipe as mp
    from mediapipe.tasks import python
    from mediapipe.tasks.python import vision

    options = vision.HandLandmarkerOptions(
        base_options=python.BaseOptions(model_asset_path=str(config.HAND_TASK)),
        running_mode=vision.RunningMode.IMAGE,
        num_hands=1,
        min_hand_detection_confidence=0.3,
        min_hand_presence_confidence=0.3,
    )
    return vision.HandLandmarker.create_from_options(options), mp


def _decode(image_bytes: bytes) -> tuple[np.ndarray, int, int]:
    try:
        image = Image.open(BytesIO(image_bytes))
        image = ImageOps.exif_transpose(image).convert("RGB")
    except Exception as exc:  # noqa: BLE001
        raise VisionError("bad_image", "could not read image") from exc
    image = _limit_edge(image, config.MAX_IMAGE_EDGE)
    array = np.asarray(image)
    return array, image.width, image.height


def _limit_edge(image: Image.Image, max_edge: int) -> Image.Image:
    if max(image.size) <= max_edge:
        return image
    scale = max_edge / max(image.size)
    size = (max(1, int(image.width * scale)), max(1, int(image.height * scale)))
    return image.resize(size, Image.Resampling.LANCZOS)


def _mp_image(pair, rgb: np.ndarray):
    _, mp = pair
    rgb = np.ascontiguousarray(rgb, dtype=np.uint8)
    return mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)


def _face_landmarks(rgb: np.ndarray) -> list[tuple[float, float, float]] | None:
    result = _face[0].detect(_mp_image(_face, rgb))
    faces = result.face_landmarks or []
    if not faces:
        return None
    points = [(p.x, p.y, p.z) for p in faces[0]]
    if len(points) < 468:
        return None
    return points


def _hand_landmarks(rgb: np.ndarray) -> list[tuple[float, float, float]] | None:
    """가이드에 맞춘 사진은 손이 프레임을 가득 채워 검출이 실패한다.

    원본으로 한 번 찾고, 없으면 회색 여백을 넣어 다시 찾는다.
    그래도 없으면 90도 단위로 돌려 같은 순서를 반복한다.
    반환 좌표는 항상 원본 이미지 기준이다.
    """
    rgb = np.ascontiguousarray(rgb, dtype=np.uint8)
    height, width = rgb.shape[:2]
    for turns in (0, 2, 1, 3):
        turned = rgb if turns == 0 else np.ascontiguousarray(np.rot90(rgb, turns))
        found = _detect_hand(turned)
        if found is not None:
            return _unrot_points(found, width, height, turns)
        padded, pad_x, pad_y = _pad_hand_image(turned)
        found = _detect_hand(padded)
        if found is not None:
            unpadded = _unmap_pad(found, turned.shape[1], turned.shape[0], pad_x, pad_y)
            return _unrot_points(unpadded, width, height, turns)
    return None


def _detect_hand(rgb: np.ndarray) -> list[tuple[float, float, float]] | None:
    result = _hand[0].detect(_mp_image(_hand, rgb))
    hands = result.hand_landmarks or []
    if not hands:
        return None
    points = [(p.x, p.y, p.z) for p in hands[0]]
    if len(points) < 21:
        return None
    return points


def _pad_hand_image(rgb: np.ndarray, ratio: float = 0.55) -> tuple[np.ndarray, int, int]:
    height, width = rgb.shape[:2]
    pad_y = max(1, int(height * ratio))
    pad_x = max(1, int(width * ratio))
    padded = np.full(
        (height + pad_y * 2, width + pad_x * 2, 3),
        114,
        dtype=np.uint8,
    )
    padded[pad_y : pad_y + height, pad_x : pad_x + width] = rgb
    return padded, pad_x, pad_y


def _unmap_pad(
    points: list[tuple[float, float, float]],
    width: int,
    height: int,
    pad_x: int,
    pad_y: int,
) -> list[tuple[float, float, float]]:
    padded_w = width + pad_x * 2
    padded_h = height + pad_y * 2
    return [
        ((x * padded_w - pad_x) / width, (y * padded_h - pad_y) / height, z)
        for x, y, z in points
    ]


def _unrot_points(
    points: list[tuple[float, float, float]],
    width: int,
    height: int,
    turns: int,
) -> list[tuple[float, float, float]]:
    turns %= 4
    if turns == 0:
        return points
    # width, height 는 원본 픽셀 크기. 정규좌표 역회전은 크기에 거의 의존하지 않는다.
    _ = (width, height)
    out: list[tuple[float, float, float]] = []
    for x, y, z in points:
        col, row = x, y
        for _ in range(turns):
            # np.rot90 한 번의 역변환: 회전된 정규좌표 -> 회전 전 정규좌표
            prev_col = 1.0 - row
            prev_row = col
            col, row = prev_col, prev_row
        out.append((col, row, z))
    return out


def _face_features(lm: list[tuple[float, float, float]]) -> dict:
    def x(index: int) -> float:
        return lm[index][0]

    def y(index: int) -> float:
        return lm[index][1]

    eye_span = abs(x(362) - x(133))
    face_height = abs(y(152) - y(10))
    nose_ratio = (y(4) - y(10)) / face_height if face_height > 1e-6 else 0.0
    return {
        "eyeSpan": eye_span,
        "faceHeight": face_height,
        "noseRatio": nose_ratio,
        "mouthWidth": abs(x(291) - x(61)),
        "symmetry": abs((x(4) - x(133)) - (x(362) - x(4))),
        "foreheadHeight": abs(y(168) - y(10)),
        "eyebrowDistance": abs(y(107) - y(133)),
    }


def _palm_features(lm: list[tuple[float, float, float]]) -> dict:
    def dist(a: int, b: int) -> float:
        dx = lm[a][0] - lm[b][0]
        dy = lm[a][1] - lm[b][1]
        return math.sqrt(dx * dx + dy * dy)

    tips = [lm[4][0], lm[8][0], lm[12][0], lm[16][0], lm[20][0]]
    mean_x = sum(tips) / len(tips)
    variance = sum((x - mean_x) ** 2 for x in tips) / len(tips)
    return {
        "palmWidth": dist(5, 17),
        "indexLength": dist(5, 8),
        "middleLength": dist(9, 12),
        "ringLength": dist(13, 16),
        "pinkyLength": dist(17, 20),
        "thumbLength": dist(1, 4),
        "fingerSpread": math.sqrt(variance),
    }
