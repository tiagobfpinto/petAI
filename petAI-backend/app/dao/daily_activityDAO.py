from __future__ import annotations

from datetime import date

from sqlalchemy import and_

from ..models import db
from ..models.daily_activity import DailyActivity


class DailyActivityDAO:
    @staticmethod
    def get_by_id(activity_id: int) -> DailyActivity | None:
        return DailyActivity.query.filter_by(id=activity_id).first()

    @staticmethod
    def list_for_user_on_date(user_id: int, target_date: date) -> list[DailyActivity]:
        return (
            DailyActivity.query.filter(
                and_(
                    DailyActivity.user_id == user_id,
                    DailyActivity.todo_date == target_date,
                )
            )
            .order_by(DailyActivity.id.asc())
            .all()
        )

    @staticmethod
    def create(
        *,
        user_id: int,
        interest_id: int,
        activity_type_id: int,
        goal_id: int | None,
        title: str,
        scheduled_for: date,
        todo_date: date | None = None,
    ) -> DailyActivity:
        activity = DailyActivity(
            user_id=user_id,
            interest_id=interest_id,
            activity_type_id=activity_type_id,
            goal_id=goal_id,
            title=title,
            scheduled_for=scheduled_for,
            todo_date=todo_date or scheduled_for,
            status="pending",
            xp_awarded=0,
        )
        db.session.add(activity)
        db.session.flush()
        return activity

    @staticmethod
    def mark_completed(activity: DailyActivity, xp_awarded: int | None = None) -> DailyActivity:
        from datetime import datetime, timezone

        activity.status = "completed"
        activity.completed_at = datetime.now(timezone.utc)
        if xp_awarded is not None:
            activity.xp_awarded = xp_awarded
        db.session.add(activity)
        return activity
