from __future__ import annotations

from sqlalchemy import or_

from ..models import db
from ..models.user import PlanType, User


class UserDAO:
    @staticmethod
    def create(username: str, email: str, full_name: str | None, plan: PlanType = PlanType.FREE) -> User:
        user = User(username=username, email=email.lower(), full_name=full_name, plan=plan)
        db.session.add(user)
        return user

    @staticmethod
    def save(user: User) -> User:
        db.session.add(user)
        return user

    @staticmethod
    def get_by_id(user_id: int) -> User | None:
        return User.query.get(user_id)

    @staticmethod
    def get_by_email(email: str) -> User | None:
        return User.query.filter_by(email=email.lower()).first()

    @staticmethod
    def get_by_username(username: str) -> User | None:
        return User.query.filter_by(username=username).first()

    @staticmethod
    def get_by_identifier(identifier: str) -> User | None:
        lowered = identifier.lower()
        return User.query.filter(or_(User.email == lowered, User.username == identifier)).first()

    @staticmethod
    def list_all() -> list[User]:
        return User.query.order_by(User.id.asc()).all()

    @staticmethod
    def user_exists(username: str, email: str) -> bool:
        return (
            User.query.filter(or_(User.username == username, User.email == email.lower()))
            .limit(1)
            .first()
            is not None
        )
