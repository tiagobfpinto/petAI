from __future__ import annotations

from typing import Iterable

from ..config import ALLOWED_INTEREST_LEVELS, BASE_INTERESTS
from ..dao.interestDAO import InterestDAO
from ..dao.userDAO import UserDAO
from ..models import db
from ..models.interest import Interest


class InterestService:
    @staticmethod
    def default_interests() -> list[str]:
        return BASE_INTERESTS.copy()

    @staticmethod
    def validate_interest_entries(entries: Iterable[dict]) -> None:
        entries = list(entries)
        if not entries:
            raise ValueError("interests must be a non-empty list")

        for entry in entries:
            if not isinstance(entry, dict):
                raise ValueError("each interest entry must be an object")
            name = (entry.get("name") or "").strip()
            level = (entry.get("level") or "").strip().lower()
            if not name:
                raise ValueError("interest name is required")
            if level not in ALLOWED_INTEREST_LEVELS:
                allowed = ", ".join(ALLOWED_INTEREST_LEVELS)
                raise ValueError(f"interest level '{level}' is invalid. Allowed: {allowed}")

    @staticmethod
    def save_user_interests(user_id: int, entries: Iterable[dict]) -> list[Interest]:
        user = UserDAO.get_by_id(user_id)
        if not user:
            raise LookupError("User not found")

        InterestDAO.delete_for_user(user_id)
        saved: list[Interest] = []
        for entry in entries:
            name = entry["name"].strip()
            level = entry["level"].strip().lower()
            goal = (entry.get("goal") or "").strip() or None
            saved.append(InterestDAO.create(user_id=user_id, name=name, level=level, goal=goal))

        db.session.flush()
        return saved

    @staticmethod
    def list_user_interests(user_id: int) -> list[Interest]:
        return InterestDAO.list_for_user(user_id)
