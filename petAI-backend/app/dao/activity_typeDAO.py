from __future__ import annotations

from sqlalchemy import and_

from ..models import db
from ..models.activity_type import ActivityType


class ActivityTypeDAO:
    @staticmethod
    def get_or_create(
        user_id: int,
        interest_id: int,
        name: str,
        description: str | None = None,
        *,
        level: str | None = None,
        goal: str | None = None,
        weekly_goal_value: float | None = None,
        weekly_goal_unit: str | None = None,
        weekly_schedule: str | None = None,
        rrule: str | None = None,
    ) -> ActivityType:
        existing = (
            ActivityType.query.filter(
                and_(
                    ActivityType.user_id == user_id,
                    ActivityType.interest_id == interest_id,
                    ActivityType.name == name,
                )
            )
            .limit(1)
            .first()
        )
        if existing:
            if level:
                existing.level = level
            if goal is not None:
                existing.goal = goal
            if weekly_goal_value is not None:
                existing.weekly_goal_value = weekly_goal_value
            if weekly_goal_unit is not None:
                existing.weekly_goal_unit = weekly_goal_unit
            if weekly_schedule is not None:
                existing.weekly_schedule = weekly_schedule
            if rrule is not None:
                existing.rrule = rrule
            return existing
        activity_type = ActivityType(
            user_id=user_id,
            interest_id=interest_id,
            name=name,
            description=description,
            level=level or "sometimes",
            goal=goal,
            weekly_goal_value=weekly_goal_value,
            weekly_goal_unit=weekly_goal_unit,
            weekly_schedule=weekly_schedule,
            rrule=rrule,
        )
        db.session.add(activity_type)
        db.session.flush()
        return activity_type

    @staticmethod
    def primary_for_interest(user_id: int, interest_id: int) -> ActivityType | None:
        return (
            ActivityType.query.filter(
                and_(
                    ActivityType.user_id == user_id,
                    ActivityType.interest_id == interest_id,
                )
            )
            .order_by(ActivityType.id.asc())
            .first()
        )

    @staticmethod
    def primary_for_area(user_id: int, area_id: int) -> ActivityType | None:
        return ActivityTypeDAO.primary_for_interest(user_id, area_id)

    @staticmethod
    def list_for_user(user_id: int) -> list[ActivityType]:
        return (
            ActivityType.query.filter(ActivityType.user_id == user_id)
            .order_by(ActivityType.updated_at.desc())
            .all()
        )

    @staticmethod
    def get_by_id(activity_type_id: int) -> ActivityType | None:
        return ActivityType.query.filter(ActivityType.id == activity_type_id).first()
