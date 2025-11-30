from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from statistics import mean
from typing import Any

from ..config import DEFAULT_MONTHLY_GOALS, GOAL_COMPLETION_XP
from ..dao.activityDAO import ActivityDAO
from ..dao.interestDAO import InterestDAO
from ..models import db
from ..models.interest import Interest
from ..services.pet_service import PetService


@dataclass
class GoalSnapshot:
    monthly_goal: float
    month_progress: float
    days_left: int
    recent_amounts: list[float]
    today_total: float
    week_total: float
    unit: str
    now: datetime

    @property
    def remaining(self) -> float:
        return max(self.monthly_goal - self.month_progress, 0.0)


class GoalService:
    """Compute and reward smart daily/weekly/monthly goals."""

    _HISTORY_DAYS = 14

    @staticmethod
    def _now(now: datetime | None = None) -> datetime:
        return now or datetime.now(timezone.utc)

    @staticmethod
    def _month_bounds(now: datetime) -> tuple[datetime, datetime, int]:
        start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        next_month = (start + timedelta(days=32)).replace(day=1)
        end = next_month - timedelta(seconds=1)
        days_in_month = (next_month - start).days
        return start, end, days_in_month

    @staticmethod
    def _week_bounds(now: datetime) -> tuple[datetime, datetime]:
        end = now
        start = now.replace(hour=0, minute=0, second=0, microsecond=0) - timedelta(days=6)
        return start, end

    @staticmethod
    def _today_bounds(now: datetime) -> tuple[datetime, datetime]:
        start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        return start, now

    @staticmethod
    def _friendly_amount(value: float) -> float:
        if value <= 0:
            return 0.0
        if value < 3:
            return round(value, 1)
        if value < 10:
            return float(round(value))
        return float(round(value / 5) * 5)

    @staticmethod
    def _friendly_week_amount(value: float) -> float:
        if value <= 0:
            return 0.0
        if value < 15:
            return float(round(value))
        return float(round(value / 5) * 5)

    @staticmethod
    def _clamp(value: float, low: float, high: float) -> float:
        return max(low, min(value, high))

    @classmethod
    def _ensure_interest(cls, user_id: int, interest_name: str) -> Interest:
        interest = InterestDAO.get_by_user_and_name(user_id, interest_name.strip())
        if not interest:
            raise LookupError("Interest not found for user")
        if interest.monthly_goal is None:
            interest.monthly_goal = DEFAULT_MONTHLY_GOALS.get(interest.level, 30)
        if not interest.target_unit:
            interest.target_unit = "units"
        return interest

    @classmethod
    def snapshot(cls, user_id: int, interest: Interest, now: datetime | None = None) -> GoalSnapshot:
        current_time = cls._now(now)
        month_start, month_end, days_in_month = cls._month_bounds(current_time)
        today_start, today_end = cls._today_bounds(current_time)
        week_start, week_end = cls._week_bounds(current_time)

        month_progress = ActivityDAO.sum_amount_between(user_id, interest.id, month_start, today_end)
        today_total = ActivityDAO.sum_amount_between(user_id, interest.id, today_start, today_end)
        week_total = ActivityDAO.sum_amount_between(user_id, interest.id, week_start, week_end)
        history_since = current_time - timedelta(days=cls._HISTORY_DAYS)
        recent_amounts = ActivityDAO.recent_amounts(user_id, interest.id, history_since)

        days_left = (month_end.date() - current_time.date()).days + 1
        days_left = max(days_left, 1)

        # Keep stored progress in sync so the UI can show a cached value.
        interest.month_progress = month_progress
        return GoalSnapshot(
            monthly_goal=interest.monthly_goal or DEFAULT_MONTHLY_GOALS.get(interest.level, 30),
            month_progress=month_progress,
            days_left=days_left,
            recent_amounts=recent_amounts,
            today_total=today_total,
            week_total=week_total,
            unit=interest.target_unit or "units",
            now=current_time,
        )

    @classmethod
    def _effort_range(cls, snapshot: GoalSnapshot, days_in_month: int) -> tuple[float, float, float, float]:
        history = [amt for amt in snapshot.recent_amounts if amt and amt > 0]
        if history:
            avg_recent = mean(history)
            max_recent = max(history)
        else:
            avg_recent = snapshot.monthly_goal / max(days_in_month, 28)
            max_recent = avg_recent
        min_effort = max(0.5, avg_recent * 0.8)
        max_effort = max(min_effort, max_recent * 1.2)
        return min_effort, max_effort, avg_recent, max_recent

    @classmethod
    def _suggestions_from_snapshot(cls, snapshot: GoalSnapshot) -> dict[str, Any]:
        month_start, _, days_in_month = cls._month_bounds(snapshot.now)
        min_effort, max_effort, avg_recent, max_recent = cls._effort_range(snapshot, days_in_month)

        remaining = snapshot.remaining
        if snapshot.days_left <= 0 or remaining <= 0:
            daily_raw = 0.0
        else:
            daily_needed = remaining / snapshot.days_left
            daily_raw = cls._clamp(daily_needed, min_effort, max_effort)
        daily_friendly = cls._friendly_amount(daily_raw)

        weekly_days = min(snapshot.days_left, 7)
        if remaining <= 0:
            weekly_raw = 0.0
        else:
            weekly_raw = cls._clamp(daily_friendly * weekly_days, min_effort * weekly_days, max_effort * weekly_days)
        weekly_friendly = cls._friendly_week_amount(weekly_raw)

        if remaining <= 0:
            instant_raw = 0.0
        else:
            instant_raw = cls._clamp(daily_friendly * 0.75 if daily_friendly else min_effort, min_effort, max_effort)
        instant_friendly = cls._friendly_amount(instant_raw)

        return {
            "monthly_goal": snapshot.monthly_goal,
            "month_progress": snapshot.month_progress,
            "remaining": remaining,
            "days_left": snapshot.days_left,
            "unit": snapshot.unit,
            "effort_range": {"min": round(min_effort, 2), "max": round(max_effort, 2)},
            "history": {
                "recent_average": round(avg_recent, 2),
                "recent_peak": round(max_recent, 2),
                "samples": len(snapshot.recent_amounts),
            },
            "suggestions": {
                "daily": {
                    "amount": daily_friendly,
                    "raw": round(daily_raw, 2),
                    "label": f"Corre {daily_friendly:g} {snapshot.unit} hoje",
                },
                "weekly": {
                    "amount": weekly_friendly,
                    "raw": round(weekly_raw, 2),
                    "label": f"Corre {weekly_friendly:g} {snapshot.unit} esta semana",
                },
                "instant": {
                    "amount": instant_friendly,
                    "raw": round(instant_raw, 2),
                    "label": f"Corre {instant_friendly:g} {snapshot.unit} agora",
                },
            },
            "generated_at": snapshot.now.isoformat(),
            "window_start": month_start.isoformat(),
        }

    @classmethod
    def suggestions_for_interest(cls, user_id: int, interest_name: str, now: datetime | None = None) -> dict:
        interest = cls._ensure_interest(user_id, interest_name)
        snapshot = cls.snapshot(user_id, interest, now)
        payload = cls._suggestions_from_snapshot(snapshot)
        interest.last_suggestions_generated_at = snapshot.now
        db.session.flush()
        return {"interest": interest.to_dict(), "goals": payload}

    @classmethod
    def set_monthly_goal(
        cls,
        user_id: int,
        interest_name: str,
        monthly_goal: float,
        unit: str | None = None,
        now: datetime | None = None,
    ) -> Interest:
        if monthly_goal <= 0:
            raise ValueError("monthly_goal must be greater than zero")
        interest = cls._ensure_interest(user_id, interest_name)
        interest.monthly_goal = float(monthly_goal)
        interest.target_unit = (unit or interest.target_unit or "units").strip() or "units"
        snapshot = cls.snapshot(user_id, interest, now)
        interest.last_suggestions_generated_at = snapshot.now
        db.session.flush()
        return interest

    @classmethod
    def apply_goal_rewards(
        cls,
        user_id: int,
        interest: Interest,
        pet,
        amount: float | None,
        now: datetime | None = None,
    ) -> dict:
        """Update goal progress and award bonus XP on completions."""
        current_time = cls._now(now)
        amount = amount or 0.0
        snapshot_after = cls.snapshot(user_id, interest, current_time)
        snapshot_before = GoalSnapshot(
            monthly_goal=snapshot_after.monthly_goal,
            month_progress=max(snapshot_after.month_progress - amount, 0.0),
            days_left=snapshot_after.days_left,
            recent_amounts=snapshot_after.recent_amounts,
            today_total=max(snapshot_after.today_total - amount, 0.0),
            week_total=max(snapshot_after.week_total - amount, 0.0),
            unit=snapshot_after.unit,
            now=current_time,
        )

        suggestions_before = cls._suggestions_from_snapshot(snapshot_before)
        suggestions_after = cls._suggestions_from_snapshot(snapshot_after)

        completions: dict[str, float] = {}
        bonus_xp = 0

        daily_target = suggestions_before["suggestions"]["daily"]["amount"]
        if daily_target and snapshot_before.today_total < daily_target <= snapshot_after.today_total:
            completions["daily"] = daily_target
            bonus_xp += GOAL_COMPLETION_XP["daily"]

        weekly_target = suggestions_before["suggestions"]["weekly"]["amount"]
        if weekly_target and snapshot_before.week_total < weekly_target <= snapshot_after.week_total:
            completions["weekly"] = weekly_target
            bonus_xp += GOAL_COMPLETION_XP["weekly"]

        if snapshot_before.month_progress < snapshot_after.monthly_goal <= snapshot_after.month_progress:
            completions["monthly"] = snapshot_after.monthly_goal
            bonus_xp += GOAL_COMPLETION_XP["monthly"]

        evolution_result = {"pet": pet, "evolved": False}
        if bonus_xp > 0:
            evolution_result = PetService.add_xp(pet, bonus_xp)

        interest.last_suggestions_generated_at = current_time
        interest.month_progress = snapshot_after.month_progress
        db.session.flush()

        return {
            "bonus_xp": bonus_xp,
            "completions": completions,
            "suggestions": suggestions_after,
            "pet": evolution_result["pet"],
            "evolved": evolution_result["evolved"],
        }
