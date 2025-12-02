from __future__ import annotations

from datetime import datetime, timedelta, timezone
from dateutil.rrule import rrulestr

from ..config import INTEREST_LEVEL_XP
from ..dao.activityDAO import ActivityDAO
from ..dao.activity_typeDAO import ActivityTypeDAO
from ..dao.goalDAO import GoalDAO
from ..dao.daily_activityDAO import DailyActivityDAO
from ..dao.areaDAO import AreaDAO
from ..dao.userDAO import UserDAO
from ..models import db
from ..models.activity import ActivityLog
from ..services.pet_service import PetService
from ..services.user_service import UserService


class ActivityService:
    @staticmethod
    def complete_activity(user_id: int, area_name: str) -> dict:
        user = UserDAO.get_by_id(user_id)
        if not user:
            raise LookupError("User not found")

        area = AreaDAO.get_by_user_and_name(user_id, area_name.strip())
        if not area:
            raise LookupError("area not found for user")

        activity_type = ActivityTypeDAO.primary_for_area(user_id, area.id) or ActivityTypeDAO.get_or_create(
            user_id, area.id, area.name, level="sometimes"
        )
        level = activity_type.level if activity_type else None
        base_xp = INTEREST_LEVEL_XP.get(level or "sometimes", 0)
        if base_xp <= 0:
            raise ValueError("Configured XP for area level is invalid")

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

        activity = ActivityDAO.log(user_id=user_id, interest_id=area.id, xp_earned=xp_amount)

        pet = PetService.get_pet_by_user(user_id) or PetService.create_pet(user_id)
        evolution_result = PetService.add_xp(pet, xp_amount)
        coins_awarded = max(1, xp_amount // 10)
        PetService.add_coins(evolution_result["pet"], coins_awarded)

        db.session.flush()

        return {
            "activity": activity,
            "pet": evolution_result["pet"],
            "xp_awarded": xp_amount,
            "coins_awarded": coins_awarded,
            "evolved": evolution_result["evolved"],
            "interest_id": area.id,
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
    
    

    @staticmethod
    def create_activity(
        *,
        user_id: int,
        activity_name: str,
        interest_name: str | None = None,
        interest_id: int | None = None,
        weekly_goal_value: float | None = None,
        weekly_goal_unit: str | None = None,
        days: list[str] | None = None,
        rrule: str | None = None,
    ) -> dict:
        user = UserDAO.get_by_id(user_id)
        if not user:
            raise LookupError("User not found")

        if not activity_name.strip():
            raise ValueError("activity name is required")

        area = None
        if interest_id is not None:
            area = AreaDAO.get_by_user_and_id(user_id, interest_id)
        if area is None and interest_name:
            area = AreaDAO.get_by_user_and_name(user_id, interest_name.strip())
        if area is None and interest_name:
            area = AreaDAO.create(user_id=user_id, name=interest_name.strip())
            db.session.flush()
        if not area:
            raise LookupError("Interest not found for user")

        schedule = ",".join(days) if days else None
        normalized_unit = (weekly_goal_unit or "").strip() or None
        if weekly_goal_value is not None and normalized_unit is None:
            normalized_unit = "minutes"

        activity_type = ActivityTypeDAO.get_or_create(
            user_id,
            area.id,
            activity_name.strip(),
            description=None,
            weekly_goal_value=weekly_goal_value,
            weekly_goal_unit=normalized_unit,
            weekly_schedule=schedule,
            rrule=rrule.strip() if rrule else None,
        )

        goal = None
        if weekly_goal_value is not None:
            try:
                value = float(weekly_goal_value)
            except (TypeError, ValueError):
                raise ValueError("weekly_goal_value must be numeric")
            if value <= 0:
                raise ValueError("weekly_goal_value must be greater than zero")
            unit = (normalized_unit or "minutes").strip() or "minutes"
            from datetime import timedelta

            expires_at = datetime.now(timezone.utc) + timedelta(days=30)
            goal = GoalDAO.create(
                user_id,
                activity_type.id,
                title=activity_name.strip(),
                amount=value,
                unit=unit,
                expires_at=expires_at,
            )

        if rrule:
            ActivityService._create_daily_tasks_from_rrule(
                user_id=user_id,
                area_id=area.id,
                activity_type=activity_type,
                title=activity_name.strip(),
                rrule=rrule,
                goal=goal,
            )
        else:
            # Create a single task for today when no recurrence is provided.
            today = datetime.now(timezone.utc).date()
            existing = [
                a
                for a in DailyActivityDAO.list_for_user_on_date(user_id, today)
                if a.activity_type_id == activity_type.id and a.title == activity_name.strip()
            ]
            if not existing:
                DailyActivityDAO.create(
                    user_id=user_id,
                    interest_id=area.id,
                    activity_type_id=activity_type.id,
                    goal_id=goal.id if goal else None,
                    title=activity_name.strip(),
                    scheduled_for=today,
                    todo_date=today,
                )

        db.session.flush()

        return {
            "activity_type": activity_type.to_dict(),
            "goal": goal.to_dict() if goal else None,
        }

    @staticmethod
    def _create_daily_tasks_from_rrule(
        *,
        user_id: int,
        area_id: int,
        activity_type,
        title: str,
        rrule: str,
        goal,
    ) -> None:
        start_dt = datetime.now(timezone.utc)
        end_dt = start_dt + timedelta(days=6)
        try:
            rule = rrulestr(rrule, dtstart=start_dt)
            occurrences = rule.between(start_dt - timedelta(seconds=1), end_dt, inc=True)
        except Exception:
            raise ValueError("Invalid recurrence rule")

        unique_dates = sorted({occ.date() for occ in occurrences})
        for day in unique_dates:
            existing = [
                a
                for a in DailyActivityDAO.list_for_user_on_date(user_id, day)
                if a.activity_type_id == activity_type.id and a.title == title
            ]
            if existing:
                continue
            DailyActivityDAO.create(
                user_id=user_id,
                interest_id=area_id,
                activity_type_id=activity_type.id,
                goal_id=goal.id if goal else None,
                title=title,
                scheduled_for=day,
                todo_date=day,
            )
