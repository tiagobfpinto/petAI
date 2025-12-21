from __future__ import annotations

from typing import Iterable

from ..config import ALLOWED_INTEREST_LEVELS, BASE_INTERESTS
from ..dao.activity_typeDAO import ActivityTypeDAO
from ..dao.areaDAO import AreaDAO
from ..dao.userDAO import UserDAO
from ..models import db
from ..models.areas import Area


class InterestService:
    _DAY_KEYS = ("mon", "tue", "wed", "thu", "fri", "sat", "sun")
    _SYSTEM_INTEREST_NAMES = {"daily basics"}
    _DAY_ALIASES = {
        "monday": "mon",
        "mon": "mon",
        "tuesday": "tue",
        "tue": "tue",
        "wednesday": "wed",
        "wed": "wed",
        "thursday": "thu",
        "thu": "thu",
        "friday": "fri",
        "fri": "fri",
        "saturday": "sat",
        "sat": "sat",
        "sunday": "sun",
        "sun": "sun",
        "0": "mon",
        "1": "tue",
        "2": "wed",
        "3": "thu",
        "4": "fri",
        "5": "sat",
        "6": "sun",
    }

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
            level = (entry.get("level") or "sometimes").strip().lower()
            if not name:
                raise ValueError("interest name is required")
            if level and level not in ALLOWED_INTEREST_LEVELS:
                allowed = ", ".join(ALLOWED_INTEREST_LEVELS)
                raise ValueError(f"interest level '{level}' is invalid. Allowed: {allowed}")
            normalized = name.lower()
            if normalized in seen:
                raise ValueError("duplicate interests are not allowed")
            seen.add(normalized)

            plan = entry.get("plan")
            if InterestService._is_running_name(normalized):
                if plan:
                    InterestService._validate_running_plan(plan)
            elif plan:
                # Allow plans for other activities when provided explicitly.
                InterestService._validate_running_plan(plan)

    @staticmethod
    def save_user_interests(user_id: int, entries: Iterable[dict]) -> list[Area]:
        user = UserDAO.get_by_id(user_id)
        if not user:
            raise LookupError("User not found")

        existing = {
            interest.name.lower(): interest for interest in AreaDAO.list_for_user(user_id)
        }
        incoming_names: set[str] = set()

        saved: list[Area] = []
        for entry in entries:
            name = entry["name"].strip()
            level = (entry.get("level") or "sometimes").strip().lower()
            if level not in ALLOWED_INTEREST_LEVELS:
                level = "sometimes"
            goal = (entry.get("goal") or "").strip() or None
            weekly_goal_value: float | None = None
            weekly_goal_unit: str | None = None
            weekly_schedule: str | None = None
            plan = None
            if InterestService._is_running_name(name) or entry.get("plan"):
                plan = InterestService._normalize_running_plan(entry.get("plan"))
            if plan:
                weekly_goal_value, weekly_goal_unit, weekly_schedule = plan
            normalized = name.lower()
            incoming_names.add(normalized)

            current = existing.get(normalized)
            if current:
                current.name = name
                interest = current
            else:
                interest = AreaDAO.create(user_id=user_id, name=name)
            saved.append(interest)

            db.session.flush()
            ActivityTypeDAO.get_or_create(
                user_id,
                interest.id,
                name,
                description=None,
                level=level,
                goal=goal,
                weekly_goal_value=weekly_goal_value,
                weekly_goal_unit=weekly_goal_unit,
                weekly_schedule=weekly_schedule,
            )

        for normalized, interest in existing.items():
            if normalized not in incoming_names:
                if InterestService._is_system_interest(interest.name):
                    continue
                db.session.delete(interest)

        db.session.flush()
        return saved

    @staticmethod
    def list_user_interests(user_id: int) -> list[Area]:
        return AreaDAO.list_for_user(user_id)

    @staticmethod
    def _validate_running_plan(plan: dict | None) -> None:
        if not isinstance(plan, dict):
            raise ValueError("Running plan requires weekly goal and schedule")
        value = plan.get("weekly_goal_value")
        days = plan.get("days")
        if value is None:
            raise ValueError("Running plan requires a weekly_goal_value")
        try:
            value_float = float(value)
        except (TypeError, ValueError):
            raise ValueError("weekly_goal_value must be numeric")
        if value_float <= 0:
            raise ValueError("weekly_goal_value must be greater than zero")
        if not isinstance(days, (list, tuple)) or not days:
            raise ValueError("Running plan requires at least one training day")
        for day in days:
            InterestService._normalize_day(day)

    @staticmethod
    def _normalize_running_plan(plan: dict | None) -> tuple[float, str, str] | None:
        if not isinstance(plan, dict):
            return None
        value = plan.get("weekly_goal_value")
        unit = (plan.get("weekly_goal_unit") or "km").strip()
        days = plan.get("days")
        if value is None or not isinstance(days, (list, tuple)) or not days:
            return None
        try:
            weekly_goal_value = float(value)
        except (TypeError, ValueError):
            return None
        if weekly_goal_value <= 0:
            return None
        normalized_days: list[str] = []
        for day in days:
            normalized = InterestService._normalize_day(day)
            if normalized not in normalized_days:
                normalized_days.append(normalized)
        schedule = ",".join(normalized_days)
        return weekly_goal_value, unit or "km", schedule

    @staticmethod
    def _normalize_day(day: str | int | None) -> str:
        if day is None:
            raise ValueError("Day cannot be empty")
        if isinstance(day, int):
            if 0 <= day <= 6:
                return InterestService._DAY_KEYS[day]
            raise ValueError("Day index must be between 0 (Mon) and 6 (Sun)")
        lowered = str(day).strip().lower()
        normalized = InterestService._DAY_ALIASES.get(lowered)
        if not normalized:
            raise ValueError("Invalid day provided")
        return normalized

    @staticmethod
    def _is_running_name(name: str) -> bool:
        normalized = name.strip().lower()
        return "running" in normalized or "cardio" in normalized

    @staticmethod
    def _is_system_interest(name: str) -> bool:
        return name.strip().lower() in InterestService._SYSTEM_INTEREST_NAMES
