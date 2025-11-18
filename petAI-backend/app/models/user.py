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
    username = db.Column(db.String(50), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False, index=True)
    password_hash = db.Column(db.String(255), nullable=False)
    full_name = db.Column(db.String(120))
    created_at = db.Column(db.DateTime(timezone=True), default=_utcnow, nullable=False)
    plan = db.Column(PgEnum(PlanType, name="plan_type_enum"), default=PlanType.FREE, nullable=False)

    pet = db.relationship("Pet", back_populates="user", uselist=False, cascade="all, delete")
    interests = db.relationship("Interest", back_populates="user", cascade="all, delete-orphan")
    activities = db.relationship("ActivityLog", back_populates="user", cascade="all, delete-orphan")
    tokens = db.relationship("AuthToken", back_populates="user", cascade="all, delete-orphan")

    def set_password(self, password: str) -> None:
        self.password_hash = bcrypt.generate_password_hash(password).decode("utf-8")

    def check_password(self, password: str) -> bool:
        return bcrypt.check_password_hash(self.password_hash, password)

    def needs_interest_setup(self) -> bool:
        return len(self.interests) == 0

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "username": self.username,
            "email": self.email,
            "full_name": self.full_name,
            "plan": self.plan.value if self.plan else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
