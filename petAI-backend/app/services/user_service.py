from __future__ import annotations

from datetime import datetime, timezone
from typing import Sequence

from ..auth import get_current_user_id
from ..dao.userDAO import UserDAO
from ..models import db
from ..models.user import PlanType, User
from ..services.auth_token_service import AuthTokenService
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
    def create_guest_user() -> User:
        """Create a guest user with no credentials and bootstrap a pet."""
        user = User(
            username=None,
            email=None,
            full_name=None,
            is_guest=True,
            plan=PlanType.FREE_TRIAL,
        )
        db.session.add(user)
        db.session.flush()

        # Every user needs a pet to avoid null payloads on the client.
        PetService.create_pet(user.id)
        db.session.flush()

        return user

    @staticmethod
    def get_user_payload(user: User) -> dict:
        pet = user.pet or PetService.create_pet(user.id)
        trial_left = UserService._trial_days_left(user)
        payload = {
            "user": user.to_dict(),
            "pet": pet.to_dict(),
            "need_interests_setup": user.needs_interest_setup(),
            "trial_days_left": trial_left,
        }
        payload["user"]["trial_days_left"] = trial_left
        return payload

    @staticmethod
    def save_user_interests(user_id: int, entries: Sequence[dict]) -> list[dict]:
        InterestService.validate_interest_entries(entries)
        interests = InterestService.save_user_interests(user_id, entries)
        return [interest.to_dict() for interest in interests]

    @staticmethod
    def resolve_user_id(explicit_user_id: int | None = None) -> int | None:
        return get_current_user_id() or explicit_user_id

    @staticmethod
    def _trial_days_left(user: User, trial_length_days: int = 3) -> int:
        """Return remaining trial days from guest creation."""
        if not user.is_guest or not user.created_at:
            return 0
        now = datetime.now(timezone.utc)
        elapsed_days = (now - user.created_at).days
        remaining = trial_length_days - elapsed_days
        return remaining if remaining > 0 else 0

    @staticmethod
    def deactivate_user(user_id: int, revoke_tokens: bool = True) -> bool:
        user = UserDAO.get_by_id(user_id)
        if not user:
            return False
        user.is_active = False
        if revoke_tokens:
            # revoke all tokens for this user
            for token in list(user.tokens):
                db.session.delete(token)
        db.session.commit()
        return True

    @staticmethod
    def reactivate_user(user_id: int) -> bool:
        user = UserDAO.get_by_id(user_id)
        if not user:
            return False
        user.is_active = True
        db.session.commit()
        return True

    @staticmethod
    def mark_trial_expired(user: User) -> None:
        """Mark a user as inactive due to trial expiry without revoking tokens."""
        if not user.is_active:
            return
        user.is_active = False
        db.session.commit()
