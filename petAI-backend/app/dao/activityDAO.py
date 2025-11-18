from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import and_

from ..models import db
from ..models.activity import ActivityLog


class ActivityDAO:
    @staticmethod
    def log(user_id: int, interest_id: int, xp_earned: int) -> ActivityLog:
        entry = ActivityLog(user_id=user_id, interest_id=interest_id, xp_earned=xp_earned)
        db.session.add(entry)
        return entry

    @staticmethod
    def list_for_user(user_id: int) -> list[ActivityLog]:
        return ActivityLog.query.filter_by(user_id=user_id).order_by(ActivityLog.timestamp.desc()).all()

    @staticmethod
    def list_for_user_between(user_id: int, start: datetime, end: datetime) -> list[ActivityLog]:
        return (
            ActivityLog.query.filter(
                and_(
                    ActivityLog.user_id == user_id,
                    ActivityLog.timestamp >= start,
                    ActivityLog.timestamp <= end,
                )
            )
            .order_by(ActivityLog.timestamp.desc())
            .all()
        )

    @staticmethod
    def list_for_user_today(user_id: int) -> list[ActivityLog]:
        start, end = ActivityDAO._today_window()
        return ActivityDAO.list_for_user_between(user_id, start, end)

    @staticmethod
    def has_completed_interest_today(user_id: int, interest_id: int) -> bool:
        start, end = ActivityDAO._today_window()
        return (
            ActivityLog.query.filter(
                and_(
                    ActivityLog.user_id == user_id,
                    ActivityLog.interest_id == interest_id,
                    ActivityLog.timestamp >= start,
                    ActivityLog.timestamp <= end,
                )
            )
            .limit(1)
            .first()
            is not None
        )

    @staticmethod
    def _today_window() -> tuple[datetime, datetime]:
        now = datetime.now(timezone.utc)
        start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        return start, now
