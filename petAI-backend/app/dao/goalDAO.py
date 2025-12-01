from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import and_

from ..models import db
from ..models.goal import Goal


class GoalDAO:
    @staticmethod
    def create(
        user_id: int,
        activity_type_id: int,
        title: str | None,
        amount: float | None,
        unit: str | None,
        expires_at: datetime,
    ) -> Goal:
        goal = Goal(
            user_id=user_id,
            activity_type_id=activity_type_id,
            title=title,
            amount=amount,
            unit=unit,
            expires_at=expires_at,
        )
        db.session.add(goal)
        db.session.flush()
        return goal

    @staticmethod
    def latest_active(user_id: int, activity_type_id: int) -> Goal | None:
        now = datetime.now(timezone.utc)
        return (
            Goal.query.filter(
                and_(
                    Goal.user_id == user_id,
                    Goal.activity_type_id == activity_type_id,
                    Goal.expires_at >= now,
                )
            )
            .order_by(Goal.created_at.desc())
            .first()
        )

    @staticmethod
    def increment_progress(goal: Goal, value: float) -> Goal:
        goal.progress_value = (goal.progress_value or 0) + value
        db.session.add(goal)
        return goal
