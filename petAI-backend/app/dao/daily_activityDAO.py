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

    @staticmethod
    def delete_pending_for_type(user_id: int, activity_type_id: int, *, start_date: date | None = None) -> int:
        query = DailyActivity.query.filter(
            and_(
                DailyActivity.user_id == user_id,
                DailyActivity.activity_type_id == activity_type_id,
                DailyActivity.status == "pending",
            )
        )
        if start_date is not None:
            query = query.filter(DailyActivity.todo_date >= start_date)
        deleted = query.delete(synchronize_session=False)
        db.session.flush()
        return deleted

    @staticmethod
    def recycle_or_create_for_today(
        *,
        user_id: int,
        interest_id: int,
        activity_type_id: int,
        goal_id: int | None,
        title: str,
        target_date: date,
    ) -> DailyActivity:
        existing = (
            DailyActivity.query.filter(
                and_(
                    DailyActivity.user_id == user_id,
                    DailyActivity.activity_type_id == activity_type_id,
                    DailyActivity.todo_date == target_date,
                    DailyActivity.scheduled_for == target_date,
                    DailyActivity.title == title,
                )
            )
            .limit(1)
            .first()
        )
        if existing:
            existing.status = "pending"
            existing.completed_at = None
            existing.xp_awarded = 0
            existing.goal_id = goal_id
            existing.interest_id = interest_id
            db.session.add(existing)
            db.session.flush()
            return existing

        return DailyActivityDAO.create(
            user_id=user_id,
            interest_id=interest_id,
            activity_type_id=activity_type_id,
            goal_id=goal_id,
            title=title,
            scheduled_for=target_date,
            todo_date=target_date,
        )
