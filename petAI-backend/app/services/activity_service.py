from __future__ import annotations

from datetime import datetime, timezone

from ..config import INTEREST_LEVEL_XP
from ..dao.activityDAO import ActivityDAO
from ..dao.interestDAO import InterestDAO
from ..dao.userDAO import UserDAO
from ..models import db
from ..models.activity import ActivityLog
from ..services.pet_service import PetService
from ..services.user_service import UserService


class ActivityService:
    @staticmethod
    def complete_activity(user_id: int, interest_name: str) -> dict:
        user = UserDAO.get_by_id(user_id)
        if not user:
            raise LookupError("User not found")

        interest = InterestDAO.get_by_user_and_name(user_id, interest_name.strip())
        if not interest:
            raise LookupError("Interest not found for user")

        if ActivityDAO.has_completed_interest_today(user_id, interest.id):
            raise ValueError("You already completed this interest today")

        base_xp = INTEREST_LEVEL_XP.get(interest.level, 0)
        if base_xp <= 0:
            raise ValueError("Configured XP for interest level is invalid")

        now = datetime.now(timezone.utc)
        today = now.date()
        last_activity_date = user.last_activity_at.date() if user.last_activity_at else None

        streak = user.streak_current or 0
        if last_activity_date is None:
            streak = 1
        else:
            delta_days = (today - last_activity_date).days
            if delta_days == 0:
                streak = max(streak, 1)
            elif delta_days == 1:
                streak = streak + 1
            else:
                streak = 1
        user.streak_current = streak
        user.streak_best = max(user.streak_best or 0, streak)
        user.last_activity_at = now

        xp_multiplier = UserService.streak_multiplier(streak)
        xp_amount = int(round(base_xp * xp_multiplier))

        activity = ActivityDAO.log(user_id=user_id, interest_id=interest.id, xp_earned=xp_amount)

        pet = PetService.get_pet_by_user(user_id) or PetService.create_pet(user_id)
        evolution_result = PetService.add_xp(pet, xp_amount)

        db.session.flush()

        return {
            "activity": activity,
            "pet": evolution_result["pet"],
            "xp_awarded": xp_amount,
            "evolved": evolution_result["evolved"],
            "interest_id": interest.id,
            "streak_current": user.streak_current,
            "streak_best": user.streak_best,
            "xp_multiplier": xp_multiplier,
        }

    @staticmethod
    def today_activities(user_id: int) -> list[ActivityLog]:
        return ActivityDAO.list_for_user_today(user_id)

    @staticmethod
    def activities_between(user_id: int, start: datetime, end: datetime) -> list[ActivityLog]:
        if start.tzinfo is None or end.tzinfo is None:
            raise ValueError("start/end must be timezone-aware")
        return ActivityDAO.list_for_user_between(user_id, start, end)
