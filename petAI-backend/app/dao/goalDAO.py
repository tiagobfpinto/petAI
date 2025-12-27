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
    def get_by_id(goal_id: int) -> Goal | None:
        return Goal.query.get(goal_id)

    @staticmethod
    def latest_active(
        user_id: int,
        activity_type_id: int,
        *,
        include_redeemed: bool = True,
    ) -> Goal | None:
        now = datetime.now(timezone.utc)
        query = Goal.query.filter(
            and_(
                Goal.user_id == user_id,
                Goal.activity_type_id == activity_type_id,
                Goal.expires_at >= now,
            )
        )
        if not include_redeemed:
            query = query.filter(Goal.redeemed_at.is_(None))
        return query.order_by(Goal.created_at.desc()).first()

    @staticmethod
    def latest_for_activity(user_id: int, activity_type_id: int) -> Goal | None:
        return (
            Goal.query.filter(
                and_(
                    Goal.user_id == user_id,
                    Goal.activity_type_id == activity_type_id,
                )
            )
            .order_by(Goal.created_at.desc())
            .first()
        )

    @staticmethod
    def list_redeemed_between(
        user_id: int,
        start: datetime,
        end: datetime,
    ) -> list[Goal]:
        return (
            Goal.query.filter(
                and_(
                    Goal.user_id == user_id,
                    Goal.redeemed_at.isnot(None),
                    Goal.redeemed_at >= start,
                    Goal.redeemed_at <= end,
                )
            )
            .order_by(Goal.redeemed_at.desc())
            .all()
        )

    @staticmethod
    def increment_progress(goal: Goal, value: float) -> Goal:
        goal.progress_value = (goal.progress_value or 0) + value
        if (
            goal.completed_at is None
            and goal.amount is not None
            and goal.amount > 0
            and (goal.progress_value or 0) >= goal.amount
        ):
            goal.completed_at = datetime.now(timezone.utc)
        db.session.add(goal)
        return goal

    @staticmethod
    def mark_completed(goal: Goal) -> Goal:
        if goal.completed_at is None:
            goal.completed_at = datetime.now(timezone.utc)
        db.session.add(goal)
        return goal

    @staticmethod
    def mark_redeemed(goal: Goal) -> Goal:
        now = datetime.now(timezone.utc)
        if goal.completed_at is None:
            goal.completed_at = now
        if goal.redeemed_at is None:
            goal.redeemed_at = now
        db.session.add(goal)
        return goal
