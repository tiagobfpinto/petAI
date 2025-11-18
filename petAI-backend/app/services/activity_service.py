from __future__ import annotations

from datetime import datetime

from ..config import INTEREST_LEVEL_XP
from ..dao.activityDAO import ActivityDAO
from ..dao.interestDAO import InterestDAO
from ..dao.userDAO import UserDAO
from ..models import db
from ..models.activity import ActivityLog
from ..services.pet_service import PetService


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

        xp_amount = INTEREST_LEVEL_XP.get(interest.level, 0)
        if xp_amount <= 0:
            raise ValueError("Configured XP for interest level is invalid")

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
        }

    @staticmethod
    def today_activities(user_id: int) -> list[ActivityLog]:
        return ActivityDAO.list_for_user_today(user_id)

    @staticmethod
    def activities_between(user_id: int, start: datetime, end: datetime) -> list[ActivityLog]:
        if start.tzinfo is None or end.tzinfo is None:
            raise ValueError("start/end must be timezone-aware")
        return ActivityDAO.list_for_user_between(user_id, start, end)
