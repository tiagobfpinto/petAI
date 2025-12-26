from __future__ import annotations

from datetime import datetime, timezone
from enum import Enum

from sqlalchemy import Enum as PgEnum

from . import bcrypt, db


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class PlanType(str, Enum):
    FREE = "FREE"
    FREE_TRIAL = "FREE_TRIAL"
    PREMIUM = "PREMIUM"


class User(db.Model):
    __tablename__ = "users"

    id = db.Column(db.Integer, primary_key=True)

    # IMPORTANT: guests don't have username/email/password, so nullable=True MUST be allowed
    username = db.Column(db.String(50), unique=True, nullable=True)
    email = db.Column(db.String(120), unique=True, nullable=True, index=True)
    password_hash = db.Column(db.String(255), nullable=True)

    full_name = db.Column(db.String(120))

    is_guest = db.Column(db.Boolean, default=True, nullable=False)
    is_active = db.Column(db.Boolean, default=True, nullable=False)
    streak_current = db.Column(db.Integer, default=0, nullable=False)
    streak_best = db.Column(db.Integer, default=0, nullable=False)
    last_activity_at = db.Column(db.DateTime(timezone=True))
    age = db.Column(db.Integer)
    gender = db.Column(db.String(32))
    coins = db.Column(db.Integer, default=0, nullable=False)
    activity_count = db.Column(db.Integer, default=0, nullable=False)

    created_at = db.Column(db.DateTime(timezone=True), default=_utcnow, nullable=False)
    plan = db.Column(PgEnum(PlanType, name="plan_type_enum"), default=PlanType.FREE, nullable=False)

    pet = db.relationship("Pet", back_populates="user", uselist=False, cascade="all, delete")
    areas = db.relationship("Area", back_populates="user", cascade="all, delete-orphan")
    activities = db.relationship("ActivityLog", back_populates="user", cascade="all, delete-orphan")
    tokens = db.relationship("AuthToken", back_populates="user", cascade="all, delete-orphan")

    __table_args__ = (
        db.CheckConstraint("coins >= 0", name="ck_user_coins_non_negative"),
    )

    def set_password(self, password: str) -> None:
        self.password_hash = bcrypt.generate_password_hash(password).decode("utf-8")
        self.is_guest = False  # When setting password, user is no longer a guest

    def check_password(self, password: str) -> bool:
        return bcrypt.check_password_hash(self.password_hash, password)

    def needs_interest_setup(self) -> bool:
        return len(self.areas) == 0

    @property
    def interests(self):
        # Backwards compatibility with older code paths
        return self.areas

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "username": self.username,
            "email": self.email,
            "full_name": self.full_name,
            "plan": self.plan.value if self.plan else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "is_guest": self.is_guest,
            "is_active": self.is_active,
            "age": self.age,
            "gender": self.gender,
            "streak_current": self.streak_current,
            "streak_best": self.streak_best,
            "last_activity_at": self.last_activity_at.isoformat() if self.last_activity_at else None,
            "coins": self.coins,
            "activity_count": self.activity_count,
        }
