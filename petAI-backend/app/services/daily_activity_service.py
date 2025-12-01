from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

from ..dao.activity_typeDAO import ActivityTypeDAO
from ..dao.daily_activityDAO import DailyActivityDAO
from ..dao.goalDAO import GoalDAO
from ..dao.interestDAO import InterestDAO
from ..models.daily_activity import DailyActivity
from ..services.activity_service import ActivityService


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
    def _plan_days(cls, interest) -> list[str]:
        try:
            plan = interest._plan_dict()
        except Exception:
            plan = None
        if not plan:
            return []
        return [d.lower() for d in plan.get("days", []) if isinstance(d, str) and d]

    @classmethod
    def _plan_value(cls, interest):
        try:
            plan = interest._plan_dict()
        except Exception:
            return None, None
        if not plan:
            return None, None
        return plan.get("weekly_goal_value"), plan.get("weekly_goal_unit")

    @classmethod
    def ensure_for_date(cls, user_id: int, target_date: date) -> list[DailyActivity]:
        day_key = cls._day_key(target_date)
        interests = InterestDAO.list_for_user(user_id)
        existing_for_day = DailyActivityDAO.list_for_user_on_date(user_id, target_date)
        for interest in interests:
            days = cls._plan_days(interest)
            if days and day_key not in days:
                continue
            title = (interest.goal or "").strip() or interest.name
            activity_type_id = cls.ensure_activity_type(user_id, interest.id, interest.name)
            amount, unit = cls._plan_value(interest)
            goal = cls.ensure_goal(user_id, activity_type_id, title=title, amount=amount, unit=unit)
            # avoid duplicates
            existing = [
                a for a in existing_for_day if a.activity_type_id == activity_type_id and a.title == title
            ]
            if existing:
                continue
            existing_for_day.append(
                DailyActivityDAO.create(
                    user_id=user_id,
                    interest_id=interest.id,
                    activity_type_id=activity_type_id,
                    goal_id=goal.id if goal else None,
                    title=title,
                    scheduled_for=target_date,
                )
            )
        return DailyActivityDAO.list_for_user_on_date(user_id, target_date)

    @classmethod
    def list_today(cls, user_id: int) -> list[DailyActivity]:
        today = cls._today()
        activities = DailyActivityDAO.list_for_user_on_date(user_id, today)
        if activities:
            return activities
        return cls.ensure_for_date(user_id, today)

    @classmethod
    def complete_daily_activity(cls, user_id: int, activity_id: int) -> dict:
        activity = DailyActivityDAO.get_by_id(activity_id)
        if not activity or activity.user_id != user_id:
            raise LookupError("Daily activity not found")
        if activity.status == "completed":
            raise ValueError("Activity already completed")

        interest = activity.interest
        if not interest:
            raise LookupError("Interest not found for activity")

        result = ActivityService.complete_activity(user_id, interest.name)
        DailyActivityDAO.mark_completed(activity, xp_awarded=result.get("xp_awarded"))
        goal_progress = 0.0
        if activity.goal:
            increment = 0.0
            if activity.goal.amount:
                # divide weekly amount by count of scheduled days if possible
                increment = max(activity.goal.amount / 7.0, 1.0) if activity.goal.amount else 1.0
            goal_progress = increment
            GoalDAO.increment_progress(activity.goal, increment)

        activity_payload = None
        activity_obj = result.get("activity")
        if activity_obj is not None and hasattr(activity_obj, "to_dict"):
            activity_payload = activity_obj.to_dict()

        return {
            "completion": {
                "pet": result["pet"].to_dict() if result.get("pet") else None,
                "xp_awarded": result.get("xp_awarded"),
                "coins_awarded": result.get("coins_awarded"),
                "interest_id": result.get("interest_id"),
                "activity": activity_payload,
                "streak_current": result.get("streak_current"),
                "streak_best": result.get("streak_best"),
                "xp_multiplier": result.get("xp_multiplier"),
                "evolved": result.get("evolved"),
            },
            "daily_activity": activity.to_dict(),
            "goal_progress_increment": goal_progress,
        }
