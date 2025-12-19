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

    @staticmethod
    def search_by_username(query: str, limit: int = 10) -> list[User]:
        if not query:
            return []
        like = f"%{query}%"
        return (
            User.query.filter(User.username.isnot(None), User.username.ilike(like))
            .order_by(User.username.asc())
            .limit(limit)
            .all()
        )
        
    @staticmethod
    def get_coins(user_id: int) -> int | None:
        user = User.query.filter_by(id=user_id).first()
        if user:
          
            return user.coins
        return None
    
    @staticmethod
    def update_coins(user_id: int, new_coins: int) -> None:
        user = User.query.filter_by(id=user_id).first()
        if user:
            user.coins = new_coins
            db.session.add(user)
            db.session.commit()

