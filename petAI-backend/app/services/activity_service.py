from __future__ import annotations

from datetime import datetime, timedelta, timezone, date
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
from ..services.chest_service import ChestService


class ActivityService:
    @staticmethod
    def complete_activity(
        user_id: int,
        area_name: str,
        activity_title: str | None = None,
        *,
        effort_value: float | None = None,
        target_value: float | None = None,
        effort_unit: str | None = None,
        increment_goal: bool = True,
    ) -> dict:
        user = UserDAO.get_by_id(user_id)
        if not user:
            raise LookupError("User not found")

        area = AreaDAO.get_by_user_and_name(user_id, area_name.strip())
        if not area:
            raise LookupError("area not found for user")

        activity_type = ActivityTypeDAO.primary_for_area(user_id, area.id) or ActivityTypeDAO.get_or_create(
            user_id, area.id, area.name, level="sometimes"
        )
        if target_value is None and getattr(activity_type, "_plan_dict", None):
            try:
                plan = activity_type._plan_dict()
                per_day = plan.get("per_day_goal_value")
                if per_day is None:
                    days = plan.get("days") or []
                    weekly_total = plan.get("weekly_goal_value")
                    if weekly_total is not None and days:
                        per_day = float(weekly_total) / max(len(days), 1)
                if per_day:
                    target_value = float(per_day)
                if effort_unit is None:
                    effort_unit = plan.get("weekly_goal_unit")
            except Exception:
                pass
        if effort_value is not None:
            try:
                effort_value = float(effort_value)
            except (TypeError, ValueError):
                effort_value = None
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
        effort_boost = 1.0
        if effort_value is not None and target_value is not None and target_value > 0:
            try:
                ratio = float(effort_value) / float(target_value)
                effort_boost = min(2.0, max(0.5, ratio))
            except Exception:
                effort_boost = 1.0
        xp_amount = max(1, int(round(base_xp * xp_multiplier * effort_boost)))

        activity = ActivityDAO.log(
            user_id=user_id,
            interest_id=area.id,
            xp_earned=xp_amount,
            activity_name=activity_title,
        )

        activity_count = (user.activity_count or 0) + 1
        user.activity_count = activity_count

        if increment_goal and activity_type:
            goal = GoalDAO.latest_active(user_id, activity_type.id, include_redeemed=False)
            if goal and goal.amount and goal.amount > 0:
                increment = None
                if effort_value is not None and effort_value > 0:
                    increment = effort_value
                elif target_value is not None and target_value > 0:
                    increment = target_value
                else:
                    days = []
                    if getattr(activity_type, "_plan_dict", None):
                        try:
                            plan = activity_type._plan_dict()
                        except Exception:
                            plan = None
                        if plan:
                            days = [d for d in plan.get("days", []) if isinstance(d, str) and d]
                    divisor = len(days) if days else 7.0
                    try:
                        increment = max(float(goal.amount) / divisor, 1.0)
                    except Exception:
                        increment = 1.0
                GoalDAO.increment_progress(goal, float(increment or 0.0))

        pet = PetService.get_pet_by_user(user_id) or PetService.create_pet(user_id)
        evolution_result = PetService.add_xp(pet, xp_amount)
        pet = evolution_result["pet"]
        coins_awarded = max(5, xp_amount)
        UserService.add_coins(user, coins_awarded)

        chest_payload = None
        grant_due = activity_count % ChestService.CHEST_INTERVAL == 0
        bonus_chance = ChestService.should_grant_bonus_chest()
        if grant_due or bonus_chance:
            chest_payload = ChestService.grant_chest(user_id=user.id)

        next_chest_in = ChestService.CHEST_INTERVAL - (activity_count % ChestService.CHEST_INTERVAL)
        if next_chest_in == ChestService.CHEST_INTERVAL:
            next_chest_in = 0

        db.session.flush()

        return {
            "activity": activity,
            "pet": pet,
            "xp_awarded": xp_amount,
            "coins_awarded": coins_awarded,
            "coins_balance": user.coins,
            "evolved": evolution_result["evolved"],
            "interest_id": area.id,
            "streak_current": user.streak_current,
            "streak_best": user.streak_best,
            "xp_multiplier": xp_multiplier,
            "effort_value": effort_value,
            "effort_target": target_value,
            "effort_unit": effort_unit,
            "effort_boost": effort_boost,
            "chest": chest_payload,
            "next_chest_in": next_chest_in,
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
            existing_goal = GoalDAO.latest_active(user_id, activity_type.id)
            skip_goal_creation = False
            if existing_goal and existing_goal.amount and existing_goal.unit:
                if (
                    abs(float(existing_goal.amount) - value) <= 0.0001
                    and existing_goal.unit.strip().lower() == unit.lower()
                ):
                    if existing_goal.redeemed_at:
                        skip_goal_creation = True
                    else:
                        goal = existing_goal
            if goal is None and not skip_goal_creation:
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
            DailyActivityDAO.recycle_or_create_for_today(
                user_id=user_id,
                interest_id=area.id,
                activity_type_id=activity_type.id,
                goal_id=goal.id if goal else None,
                title=activity_name.strip(),
                target_date=today,
            )
        # Always seed a pending task for today so it appears immediately, even if the recurrence skips today.
        today = datetime.now(timezone.utc).date()
        DailyActivityDAO.recycle_or_create_for_today(
            user_id=user_id,
            interest_id=area.id,
            activity_type_id=activity_type.id,
            goal_id=goal.id if goal else None,
            title=activity_name.strip(),
            target_date=today,
        )

        db.session.flush()

        return {
            "activity_type": activity_type.to_dict(),
            "goal": goal.to_dict() if goal else None,
        }

    @staticmethod
    def update_activity_type(
        *,
        user_id: int,
        activity_type_id: int,
        activity_name: str,
        interest_name: str | None = None,
        interest_id: int | None = None,
        weekly_goal_value: float | None = None,
        weekly_goal_unit: str | None = None,
        days: list[str] | None = None,
        rrule: str | None = None,
    ) -> dict:
        activity_type = ActivityTypeDAO.get_by_id(activity_type_id)
        if not activity_type or activity_type.user_id != user_id:
            raise LookupError("Activity not found")

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

        activity_type.name = activity_name.strip()
        activity_type.interest_id = area.id
        activity_type.weekly_goal_value = weekly_goal_value
        activity_type.weekly_goal_unit = normalized_unit
        activity_type.weekly_schedule = schedule
        activity_type.rrule = rrule.strip() if rrule else None

        goal = None
        if weekly_goal_value is not None:
            try:
                value = float(weekly_goal_value)
            except (TypeError, ValueError):
                raise ValueError("weekly_goal_value must be numeric")
            if value <= 0:
                raise ValueError("weekly_goal_value must be greater than zero")
            unit = (normalized_unit or "minutes").strip() or "minutes"
            existing_goal = GoalDAO.latest_active(user_id, activity_type.id)
            skip_goal_creation = False
            if existing_goal and existing_goal.amount and existing_goal.unit:
                if (
                    abs(float(existing_goal.amount) - value) <= 0.0001
                    and existing_goal.unit.strip().lower() == unit.lower()
                ):
                    if existing_goal.redeemed_at:
                        skip_goal_creation = True
                    else:
                        goal = existing_goal
            if goal is None and not skip_goal_creation:
                expires_at = datetime.now(timezone.utc) + timedelta(days=30)
                goal = GoalDAO.create(
                    user_id,
                    activity_type.id,
                    title=activity_name.strip(),
                    amount=value,
                    unit=unit,
                    expires_at=expires_at,
                )

        # Refresh pending daily tasks for this activity type from today onward.
        today = date.today()
        DailyActivityDAO.delete_pending_for_type(user_id, activity_type.id, start_date=today)
        from ..services.daily_activity_service import DailyActivityService  # local import to avoid cycle

        DailyActivityService.ensure_week(user_id, start_date=today, days=7)
        # Ensure a task exists for today so the UI can render it immediately.
        DailyActivityDAO.recycle_or_create_for_today(
            user_id=user_id,
            interest_id=area.id,
            activity_type_id=activity_type.id,
            goal_id=goal.id if goal else None,
            title=activity_name.strip(),
            target_date=today,
        )

        db.session.flush()

        return {
            "activity_type": activity_type.to_dict(),
            "goal": goal.to_dict() if goal else None,
        }

    @staticmethod
    def delete_activity_type(*, user_id: int, activity_type_id: int) -> None:
        activity_type = ActivityTypeDAO.get_by_id(activity_type_id)
        if not activity_type or activity_type.user_id != user_id:
            raise LookupError("Activity not found")
        db.session.delete(activity_type)
        db.session.flush()

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
