from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import and_, func

from ..models import db
from ..models.activity import ActivityLog


class ActivityDAO:
    @staticmethod
    def log(user_id: int, interest_id: int, xp_earned: int, amount: float | None = None) -> ActivityLog:
        entry = ActivityLog(user_id=user_id, interest_id=interest_id, xp_earned=xp_earned, amount=amount)
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

    @staticmethod
    def sum_amount_between(user_id: int, interest_id: int, start: datetime, end: datetime) -> float:
        total = (
            db.session.query(func.coalesce(func.sum(ActivityLog.amount), 0.0))
            .filter(
                and_(
                    ActivityLog.user_id == user_id,
                    ActivityLog.interest_id == interest_id,
                    ActivityLog.timestamp >= start,
                    ActivityLog.timestamp <= end,
                    ActivityLog.amount.isnot(None),
                )
            )
            .scalar()
        )
        return float(total or 0.0)

    @staticmethod
    def recent_amounts(user_id: int, interest_id: int, since: datetime, limit: int = 30) -> list[float]:
        rows = (
            db.session.query(ActivityLog.amount)
            .filter(
                and_(
                    ActivityLog.user_id == user_id,
                    ActivityLog.interest_id == interest_id,
                    ActivityLog.amount.isnot(None),
                    ActivityLog.timestamp >= since,
                )
            )
            .order_by(ActivityLog.timestamp.desc())
            .limit(limit)
            .all()
        )
        return [row[0] for row in rows if row[0] is not None]
