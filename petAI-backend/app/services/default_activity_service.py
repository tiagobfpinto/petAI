from __future__ import annotations

from datetime import datetime, timezone

from ..dao.activity_typeDAO import ActivityTypeDAO
from ..dao.areaDAO import AreaDAO
from ..dao.userDAO import UserDAO
from ..models import db


class DefaultActivityService:
    SYSTEM_INTEREST_NAME = "Daily Basics"
    _SYSTEM_INTEREST_NAMES = {SYSTEM_INTEREST_NAME.lower()}

    BASELINE_ACTIVITIES = (
        "Drink water",
        "Take a walk outside",
    )

    @classmethod
    def is_system_interest(cls, name: str) -> bool:
        return name.strip().lower() in cls._SYSTEM_INTEREST_NAMES

    @classmethod
    def bootstrap_defaults(cls, user_id: int) -> None:
        user = UserDAO.get_by_id(user_id)
        if not user:
            raise LookupError("User not found")

        cls._ensure_baseline_interest(user_id)
        cls._ensure_interest_defaults(user_id, age=user.age, gender=user.gender)

        from ..services.daily_activity_service import DailyActivityService  # local import to avoid cycles

        today = datetime.now(timezone.utc).date()
        DailyActivityService.ensure_week(user_id, start_date=today, days=7)

    @classmethod
    def _ensure_baseline_interest(cls, user_id: int) -> None:
        interest = AreaDAO.get_by_user_and_name(user_id, cls.SYSTEM_INTEREST_NAME)
        if not interest:
            interest = AreaDAO.create(user_id=user_id, name=cls.SYSTEM_INTEREST_NAME)
            db.session.flush()

        for title in cls.BASELINE_ACTIVITIES:
            ActivityTypeDAO.get_or_create(
                user_id,
                interest.id,
                title,
                goal=title,
                level="always",
            )
        db.session.flush()

    @classmethod
    def _ensure_interest_defaults(cls, user_id: int, *, age: int | None, gender: str | None) -> None:
        interests = AreaDAO.list_for_user(user_id)
        for interest in interests:
            if cls.is_system_interest(interest.name):
                continue

            activity_type = ActivityTypeDAO.primary_for_area(user_id, interest.id) or ActivityTypeDAO.get_or_create(
                user_id,
                interest.id,
                interest.name,
            )
            key = cls._interest_key(interest.name)
            if key == "study":
                if not (activity_type.goal or "").strip():
                    activity_type.goal = "Learn something new"
            elif key == "running":
                if not (activity_type.goal or "").strip():
                    activity_type.goal = "Run"

        db.session.flush()

    @staticmethod
    def _interest_key(name: str) -> str | None:
        normalized = name.strip().lower()
        if "running" in normalized or "cardio" in normalized:
            return "running"
        if "study" in normalized or "learn" in normalized:
            return "study"
        return None

    @staticmethod
    def _suggest_running_plan(
        level: str,
        *,
        age: int | None,
        gender: str | None,
    ) -> tuple[float, str, str]:
        per_day_km_by_level = {
            "never": 1.0,
            "sometimes": 2.0,
            "usually": 3.0,
            "always": 4.0,
        }
        default_days_by_level = {
            "never": ["mon", "thu"],
            "sometimes": ["mon", "wed", "sat"],
            "usually": ["mon", "wed", "fri", "sun"],
            "always": ["mon", "tue", "wed", "thu", "fri"],
        }

        per_day_km = per_day_km_by_level.get(level, 2.0)
        if age is not None:
            if age < 25:
                per_day_km *= 1.1
            elif age > 50:
                per_day_km *= 0.7

        normalized_gender = (gender or "").strip().lower()
        if normalized_gender.startswith("female"):
            per_day_km *= 0.9

        per_day_km = round(max(0.5, float(per_day_km)), 1)
        days = default_days_by_level.get(level) or default_days_by_level["sometimes"]
        weekly_goal_value = round(max(1.0, per_day_km * len(days)), 1)
        weekly_goal_unit = "km"
        weekly_schedule = ",".join(days)
        return weekly_goal_value, weekly_goal_unit, weekly_schedule
