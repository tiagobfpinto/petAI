from __future__ import annotations

from datetime import datetime, timezone
from enum import Enum



from . import bcrypt, db


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Admin_Users(db.Model):
    __tablename__ = "admin_users"

    id = db.Column(db.Integer, primary_key=True)

    username = db.Column(db.String(50), unique=True, nullable=True)
    email = db.Column(db.String(120), unique=True, nullable=True, index=True)
    password_hash = db.Column(db.String(255), nullable=True)

    created_at = db.Column(db.DateTime(timezone=True), default=_utcnow, nullable=False)
    permissions = db.Column(db.String, nullable=True)  # e.g., "read,write,delete"

    def set_password(self, password: str) -> None:
        self.password_hash = bcrypt.generate_password_hash(password).decode("utf-8")
        self.is_guest = False  # When setting password, user is no longer a guest

    def check_password(self, password: str) -> bool:
        return bcrypt.check_password_hash(self.password_hash, password)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "username": self.username,
            "email": self.email,
            "created_at": self.created_at.isoformat(),
        }