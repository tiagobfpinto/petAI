import os
from pathlib import Path


def _load_env_file():
    """Load .env settings either via python-dotenv or a minimal fallback."""
    env_path = Path(__file__).resolve().parent / ".env"
    if not env_path.exists():
        return

    try:
        from dotenv import load_dotenv  # type: ignore
    except ModuleNotFoundError:
        for line in env_path.read_text().splitlines():
            stripped = line.strip()
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
    SQLALCHEMY_DATABASE_URI = os.getenv(
        "DATABASE_URL", "sqlite:///petai.db"
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SECRET_KEY = os.getenv("SECRET_KEY", "supersecretkey")
    _raw_origins = os.getenv(
        "CORS_ORIGINS",
        ",".join(
            [
                "http://localhost:59453",
                "http://127.0.0.1:59453",
                "http://localhost:3000",
                "http://127.0.0.1:3000",
                "http://localhost:8080",
                "http://127.0.0.1:8080",
            ]
        ),
    )
    CORS_ORIGINS = [
        origin.strip()
        for origin in _raw_origins.split(",")
        if origin.strip()
    ]
