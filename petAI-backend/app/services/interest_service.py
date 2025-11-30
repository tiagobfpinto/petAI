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

        seen: set[str] = set()
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
            normalized = name.lower()
            if normalized in seen:
                raise ValueError("duplicate interests are not allowed")
            seen.add(normalized)

    @staticmethod
    def save_user_interests(user_id: int, entries: Iterable[dict]) -> list[Interest]:
        user = UserDAO.get_by_id(user_id)
        if not user:
            raise LookupError("User not found")

        existing = {
            interest.name.lower(): interest for interest in InterestDAO.list_for_user(user_id)
        }
        incoming_names: set[str] = set()

        saved: list[Interest] = []
        for entry in entries:
            name = entry["name"].strip()
            level = entry["level"].strip().lower()
            goal = (entry.get("goal") or "").strip() or None
            normalized = name.lower()
            incoming_names.add(normalized)

            current = existing.get(normalized)
            if current:
                current.name = name
                current.level = level
                current.goal = goal
                saved.append(current)
            else:
                saved.append(InterestDAO.create(user_id=user_id, name=name, level=level, goal=goal))

        for normalized, interest in existing.items():
            if normalized not in incoming_names:
                db.session.delete(interest)

        db.session.flush()
        return saved

    @staticmethod
    def list_user_interests(user_id: int) -> list[Interest]:
        return InterestDAO.list_for_user(user_id)
