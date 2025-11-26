import os
from pathlib import Path


def _load_env_file() -> None:
    """Load .env contents before Flask config initializes."""
    env_path = Path(__file__).resolve().parent.parent / ".env"
    if not env_path.exists():
        return

    try:
        from dotenv import load_dotenv  # type: ignore
    except ModuleNotFoundError:
        for raw_line in env_path.read_text(encoding="utf-8").splitlines():
            stripped = raw_line.strip()
            if not stripped or stripped.startswith("#") or "=" not in stripped:
                continue
            if stripped.startswith("export "):
                stripped = stripped[len("export ") :]
            key, value = stripped.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip().strip('\'"'))
    else:
        load_dotenv(env_path)


_load_env_file()


class Config:
    SQLALCHEMY_DATABASE_URI = os.getenv("DATABASE_URL", "sqlite:///petai.db")
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SECRET_KEY = os.getenv("SECRET_KEY", "supersecretkey")
    AUTH_TOKEN_EXPIRES_SECONDS = int(os.getenv("AUTH_TOKEN_EXPIRES_SECONDS", 30 * 24 * 60 * 60))

    


PET_EVOLUTIONS = {
    1: {"stage": "egg", "xp_required": 0},
    2: {"stage": "sprout", "xp_required": 100},
    3: {"stage": "bud", "xp_required": 250},
    4: {"stage": "plant", "xp_required": 500},
    5: {"stage": "tree", "xp_required": 1000},
}

BASE_INTERESTS = [
    "Running",
    "Study",
    "Work on a project",
    "Skincare",
    "Eat Healthy",
    "Wake up early",
    "Make my bed",
]

ALLOWED_INTEREST_LEVELS = ("never", "sometimes", "usually", "always")

INTEREST_LEVEL_XP = {
    "never": 20,
    "sometimes": 15,
    "usually": 10,
    "always": 5,
}
