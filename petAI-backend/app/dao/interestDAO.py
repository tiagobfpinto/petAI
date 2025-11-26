from __future__ import annotations

from sqlalchemy import func

from ..models import db
from ..models.interest import Interest


class InterestDAO:
    @staticmethod
    def create(user_id: int, name: str, level: str, goal: str | None) -> Interest:
        interest = Interest(user_id=user_id, name=name, level=level, goal=goal)
        db.session.add(interest)
        return interest

    @staticmethod
    def list_for_user(user_id: int) -> list[Interest]:
        return Interest.query.filter_by(user_id=user_id).order_by(Interest.id.asc()).all()

    @staticmethod
    def get_by_user_and_name(user_id: int, name: str) -> Interest | None:
        lowered = name.strip().lower()
        return (
            Interest.query.filter(Interest.user_id == user_id)
            .filter(func.lower(Interest.name) == lowered)
            .first()
        )

    @staticmethod
    def delete_for_user(user_id: int) -> None:
        Interest.query.filter_by(user_id=user_id).delete(synchronize_session=False)

    @staticmethod
    def save(interest: Interest) -> Interest:
        db.session.add(interest)
        return interest
