import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODEL_PATH = ROOT / "gemma-4-E2B-it.litertlm"
# 명세의 Gemma 4 E2B. 폴더에 파일이 없을 때만 받는다.
MODEL_URL = os.environ.get(
    "AURA_MODEL_URL",
    "https://drive.usercontent.google.com/download"
    "?id=1bsRm7Ri0rm13fkcfAvkABZeJa4RnNflE&export=download&confirm=t",
).strip()
# 짧은 HTML 오류 페이지를 모델로 착각하지 않도록 한다. E2B는 약 2.5GB다.
MODEL_MIN_BYTES = int(os.environ.get("AURA_MODEL_MIN_BYTES", str(500 * 1024 * 1024)))
MODELS_DIR = ROOT / "models"
CACHE_DIR = ROOT / ".cache"
FACE_TASK = MODELS_DIR / "face_landmarker.task"
HAND_TASK = MODELS_DIR / "hand_landmarker.task"

FACE_TASK_URL = (
    "https://storage.googleapis.com/mediapipe-models/"
    "face_landmarker/face_landmarker/float16/1/face_landmarker.task"
)
HAND_TASK_URL = (
    "https://storage.googleapis.com/mediapipe-models/"
    "hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task"
)

HOST = "0.0.0.0"
PORT = 8787
# AURA_GEMMA_BACKEND=cpu 로 GPU 를 건너뛸 수 있다.
GEMMA_BACKENDS = (
    (os.environ.get("AURA_GEMMA_BACKEND", "").strip().upper(),)
    if os.environ.get("AURA_GEMMA_BACKEND", "").strip()
    else ("GPU", "CPU")
)
MAX_OUTPUT_TOKENS = 1536
TEMPERATURE = 0.7
TOP_K = 20
MAX_IMAGE_EDGE = 1280
CHAT_HISTORY_TURNS = 12
