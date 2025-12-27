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
from ..services.subscription_service import SubscriptionService


class UserService:
    @staticmethod
    def create_user(username: str, email: str, full_name: str | None, password: str) -> tuple[User, dict]:
        UserService.validate_password(password)
        if UserDAO.user_exists(username, email):
            raise ValueError("User with provided username or email already exists")

        user = UserDAO.create(username=username, email=email, full_name=full_name)
        user.set_password(password)
        db.session.flush()

        pet = PetService.create_pet(user.id)
        db.session.flush()

        return user, PetService.pet_payload(pet)

    @staticmethod
    def validate_password(password: str) -> None:
        if not password or len(password) < 8:
            raise ValueError("Password must be at least 8 characters")
        if not any(char.isdigit() for char in password):
            raise ValueError("Password must include at least one number")

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
        streak_multiplier = UserService.streak_multiplier(user.streak_current or 0)
        payload = {
            "user": user.to_dict(),
            "pet": PetService.pet_payload(pet),
            "need_interests_setup": user.needs_interest_setup(),
            "trial_days_left": trial_left,
            "streak_multiplier": streak_multiplier,
            "subscription": SubscriptionService.subscription_payload(user.id),
        }
        payload["user"]["trial_days_left"] = trial_left
        payload["user"]["streak_multiplier"] = streak_multiplier
        return payload

    @staticmethod
    def save_user_interests(user_id: int, entries: Sequence[dict]) -> list[dict]:
        InterestService.validate_interest_entries(entries)
        InterestService.save_user_interests(user_id, entries)

        from ..services.default_activity_service import DefaultActivityService

        DefaultActivityService.bootstrap_defaults(user_id)
        interests = InterestService.list_user_interests(user_id)
        return [interest.to_dict() for interest in interests]

    @staticmethod
    def resolve_user_id(explicit_user_id: int | None = None) -> int | None:
        return get_current_user_id() or explicit_user_id

    @staticmethod
    def update_profile(user_id: int, age: int | None = None, gender: str | None = None) -> dict:
        user = UserDAO.get_by_id(user_id)
        if not user:
            raise LookupError("User not found")

        if age is not None:
            if age <= 0:
                raise ValueError("age must be greater than zero")
            user.age = age
        if gender is not None:
            gender = gender.strip()
            if gender:
                user.gender = gender
        db.session.flush()
        return user.to_dict()

    @staticmethod
    def _trial_days_left(user: User, trial_length_days: int = 3) -> int:
        """Return remaining trial days from guest creation."""
        if not user.is_guest or not user.created_at:
            return 0
        now = datetime.now(timezone.utc)
        created_at = user.created_at
        if created_at.tzinfo is None:
            created_at = created_at.replace(tzinfo=timezone.utc)
        elapsed_days = (now - created_at).days
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

    @staticmethod
    def add_coins(user: User, amount: int) -> User:
        if amount == 0:
            return user
        user.coins = max(0, (user.coins or 0) + amount)
        UserDAO.save(user)
        return user

    @staticmethod
    def spend_coins(user: User, amount: int) -> User:
        if amount <= 0:
            return user
        if (user.coins or 0) < amount:
            raise ValueError("Not enough coins")
        user.coins = max(0, (user.coins or 0) - amount)
        UserDAO.save(user)
        return user

    @staticmethod
    def streak_multiplier(streak: int, cap: int = 10) -> float:
        """Compute XP multiplier from streak (1x to 2x at cap)."""
        streak = max(0, min(streak, cap))
        if streak <= 1:
            return 1.0
        # scale linearly so streak=cap yields 2.0
        return round(1.0 + (streak - 1) / (cap - 1), 2)
