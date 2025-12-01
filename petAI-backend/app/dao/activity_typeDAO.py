from __future__ import annotations

from sqlalchemy import and_

from ..models import db
from ..models.activity_type import ActivityType


class ActivityTypeDAO:
    @staticmethod
    def get_or_create(user_id: int, interest_id: int, name: str, description: str | None = None) -> ActivityType:
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
            return existing
        activity_type = ActivityType(
            user_id=user_id,
            interest_id=interest_id,
            name=name,
            description=description,
        )
        db.session.add(activity_type)
        db.session.flush()
        return activity_type
