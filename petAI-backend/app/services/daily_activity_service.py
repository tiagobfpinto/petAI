from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

from ..dao.activity_typeDAO import ActivityTypeDAO
from ..dao.daily_activityDAO import DailyActivityDAO
from ..dao.goalDAO import GoalDAO
from ..dao.areaDAO import AreaDAO
from ..models.daily_activity import DailyActivity
from ..services.activity_service import ActivityService
from ..services.pet_service import PetService


class DailyActivityService:
    _DAY_KEYS = ("mon", "tue", "wed", "thu", "fri", "sat", "sun")

    @classmethod
    def _today(cls) -> date:
        return datetime.now(timezone.utc).date()

    @classmethod
    def _day_key(cls, target_date: date) -> str:
        return cls._DAY_KEYS[target_date.weekday()]

    @classmethod
    def ensure_activity_type(cls, user_id: int, interest_id: int, name: str) -> int:
        activity_type = ActivityTypeDAO.get_or_create(user_id, interest_id, name)
        return activity_type.id

    @classmethod
    def ensure_goal(cls, user_id: int, activity_type_id: int, *, title: str | None, amount: float | None, unit: str | None):
        existing = GoalDAO.latest_active(user_id, activity_type_id)
        if existing:
            return existing
        expires_at = datetime.now(timezone.utc) + timedelta(days=7)
        return GoalDAO.create(user_id, activity_type_id, title, amount, unit, expires_at)

    @classmethod
    def _plan_days(cls, activity_type) -> list[str]:
        try:
            plan = activity_type._plan_dict()
        except Exception:
            plan = None
        if not plan:
            return []
        return [d.lower() for d in plan.get("days", []) if isinstance(d, str) and d]

    @classmethod
    def _plan_details(cls, activity_type) -> dict | None:
        try:
            plan = activity_type._plan_dict()
        except Exception:
            return None
        if not plan:
            return None
        days = [d.lower() for d in plan.get("days", []) if isinstance(d, str) and d]
        weekly_value = plan.get("weekly_goal_value")
        unit = plan.get("weekly_goal_unit")
        per_day = None
        if weekly_value is not None and days:
            try:
                per_day = round(float(weekly_value) / max(len(days), 1), 2)
            except (TypeError, ValueError):
                per_day = None
        return {
            "days": days,
            "weekly_value": weekly_value,
            "unit": unit,
            "per_day": per_day,
        }

    @classmethod
    def _day_label(cls, day_key: str) -> str:
        labels = {
            "mon": "Monday",
            "tue": "Tuesday",
            "wed": "Wednesday",
            "thu": "Thursday",
            "fri": "Friday",
            "sat": "Saturday",
            "sun": "Sunday",
        }
        return labels.get(day_key.lower(), day_key)

    @staticmethod
    def _format_amount(value: float | int | None) -> str:
        if value is None:
            return ""
        if isinstance(value, int) or value.is_integer():
            return str(int(value))
        return f"{value:.2f}".rstrip("0").rstrip(".")

    @classmethod
    def ensure_for_date(cls, user_id: int, target_date: date) -> list[DailyActivity]:
        day_key = cls._day_key(target_date)
        interests = AreaDAO.list_for_user(user_id)
        existing_for_day = DailyActivityDAO.list_for_user_on_date(user_id, target_date)
        for interest in interests:
            activity_types = ActivityTypeDAO.list_for_interest(user_id, interest.id)
            if not activity_types:
                activity_types = [ActivityTypeDAO.get_or_create(user_id, interest.id, interest.name)]

            for activity_type in activity_types:
                plan = cls._plan_details(activity_type) if activity_type else None
                days = plan["days"] if plan else []
                if days and day_key not in days:
                    continue

                title_base = (activity_type.goal or "").strip() if activity_type else ""
                if not title_base:
                    title_base = (activity_type.name or "").strip() if activity_type else ""
                if not title_base:
                    title_base = interest.name

                per_day_title = title_base
                if plan and plan.get("per_day"):
                    amount_text = cls._format_amount(plan["per_day"])
                    if amount_text:
                        unit = (plan.get("unit") or "").strip()
                        day_label = cls._day_label(day_key)
                        parts = [title_base, "for", amount_text]
                        if unit:
                            parts.append(unit)
                        if day_label:
                            parts.append(day_label)
                        per_day_title = " ".join(parts)

                activity_type_id = activity_type.id if activity_type else cls.ensure_activity_type(user_id, interest.id, interest.name)
                amount = plan.get("weekly_value") if plan else None
                unit = plan.get("unit") if plan else None
                goal = cls.ensure_goal(user_id, activity_type_id, title=title_base, amount=amount, unit=unit)
                # avoid duplicates
                existing = [
                    a
                    for a in existing_for_day
                    if a.activity_type_id == activity_type_id and a.title == per_day_title
                ]
                if existing:
                    continue
                existing_for_day.append(
                    DailyActivityDAO.create(
                        user_id=user_id,
                        interest_id=interest.id,
                        activity_type_id=activity_type_id,
                        goal_id=goal.id if goal else None,
                        title=per_day_title,
                        scheduled_for=target_date,
                        todo_date=target_date,
                    )
                )
        return DailyActivityDAO.list_for_user_on_date(user_id, target_date)

    @classmethod
    def ensure_week(cls, user_id: int, start_date: date | None = None, *, days: int = 7) -> None:
        start = start_date or cls._today()
        for offset in range(days):
            target_date = start + timedelta(days=offset)
            cls.ensure_for_date(user_id, target_date)

    @classmethod
    def list_today(cls, user_id: int) -> list[DailyActivity]:
        today = cls._today()
        return cls.ensure_for_date(user_id, today)

    @classmethod
    def complete_daily_activity(
        cls,
        user_id: int,
        activity_id: int,
        *,
        logged_value: float | None = None,
        unit: str | None = None,
    ) -> dict:
        activity = DailyActivityDAO.get_by_id(activity_id)
        if not activity or activity.user_id != user_id:
            raise LookupError("Daily activity not found")
        if activity.status == "completed":
            raise ValueError("Activity already completed")

        interest = activity.interest
        activity_type = activity.activity_type
        if not interest:
            raise LookupError("Interest not found for activity")

        plan = cls._plan_details(activity_type) if activity_type else None
        per_day_target = plan.get("per_day") if plan else None
        plan_unit = (plan.get("unit") or "").strip() if plan else None
        normalized_unit = (unit or plan_unit or (activity.goal.unit if activity.goal else None) or "").strip() or None

        logged_amount = None
        if logged_value is not None:
            try:
                logged_amount = float(logged_value)
            except (TypeError, ValueError):
                logged_amount = None

        result = ActivityService.complete_activity(
            user_id,
            interest.name,
            activity_title=activity.title,
            effort_value=logged_amount,
            target_value=per_day_target,
            effort_unit=normalized_unit,
        )
        DailyActivityDAO.mark_completed(activity, xp_awarded=result.get("xp_awarded"))
        goal_progress = 0.0
        if activity.goal:
            increment: float | None = None
            if logged_amount is not None and logged_amount > 0:
                increment = logged_amount
            elif per_day_target is not None and per_day_target > 0:
                increment = per_day_target
            elif activity.goal.amount:
                days = cls._plan_days(activity_type) if activity_type else []
                divisor = len(days) if days else 7.0
                try:
                    increment = max(activity.goal.amount / divisor, 1.0)
                except Exception:
                    increment = 1.0
            goal_progress = float(increment or 0.0)
            GoalDAO.increment_progress(activity.goal, goal_progress if goal_progress else 0.0)

        activity_payload = None
        activity_obj = result.get("activity")
        if activity_obj is not None and hasattr(activity_obj, "to_dict"):
            activity_payload = activity_obj.to_dict()

        return {
            "completion": {
                "pet": PetService.pet_payload(result["pet"]) if result.get("pet") else None,
                "xp_awarded": result.get("xp_awarded"),
                "coins_awarded": result.get("coins_awarded"),
                "coins_balance": result.get("coins_balance"),
                "interest_id": result.get("interest_id"),
                "activity": activity_payload,
                "streak_current": result.get("streak_current"),
                "streak_best": result.get("streak_best"),
                "xp_multiplier": result.get("xp_multiplier"),
                "evolved": result.get("evolved"),
                "effort_value": result.get("effort_value"),
                "effort_target": result.get("effort_target"),
                "effort_unit": result.get("effort_unit"),
                "effort_boost": result.get("effort_boost"),
            },
            "daily_activity": activity.to_dict(),
            "goal_progress_increment": goal_progress,
        }
