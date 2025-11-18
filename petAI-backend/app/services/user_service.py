from __future__ import annotations

from typing import Sequence

from ..auth import get_current_user_id
from ..dao.userDAO import UserDAO
from ..models import db
from ..models.user import User
from ..services.interest_service import InterestService
from ..services.pet_service import PetService


class UserService:
    @staticmethod
    def create_user(username: str, email: str, full_name: str | None, password: str) -> tuple[User, dict]:
        if UserDAO.user_exists(username, email):
            raise ValueError("User with provided username or email already exists")

        user = UserDAO.create(username=username, email=email, full_name=full_name)
        user.set_password(password)
        db.session.flush()

        pet = PetService.create_pet(user.id)
        db.session.flush()

        return user, pet.to_dict()

    @staticmethod
    def get_user_payload(user: User) -> dict:
        pet = user.pet or PetService.create_pet(user.id)
        return {
            "user": user.to_dict(),
            "pet": pet.to_dict(),
            "need_interests_setup": user.needs_interest_setup(),
        }

    @staticmethod
    def save_user_interests(user_id: int, entries: Sequence[dict]) -> list[dict]:
        InterestService.validate_interest_entries(entries)
        interests = InterestService.save_user_interests(user_id, entries)
        return [interest.to_dict() for interest in interests]

    @staticmethod
    def resolve_user_id(explicit_user_id: int | None = None) -> int | None:
        return get_current_user_id() or explicit_user_id
