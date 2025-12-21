from __future__ import annotations

from datetime import datetime, timezone

from . import db


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


_SYSTEM_INTEREST_NAMES = {"daily basics"}


class Area(db.Model):
    __tablename__ = "areas"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    name = db.Column(db.String(120), nullable=False)
    created_at = db.Column(db.DateTime(timezone=True), default=_utcnow, nullable=False)
    updated_at = db.Column(db.DateTime(timezone=True), default=_utcnow, onupdate=_utcnow, nullable=False)

    user = db.relationship("User", back_populates="areas")
    activity_types = db.relationship(
        "ActivityType",
        back_populates="area",
        cascade="all, delete-orphan",
        order_by="ActivityType.id",
    )

    __table_args__ = (
        db.UniqueConstraint("user_id", "name", name="uq_user_interest_name"),
    )

    def to_dict(self) -> dict:
        activity_type = self.primary_activity_type
        return {
            "id": self.id,
            "user_id": self.user_id,
            "name": self.name,
            "is_system": self.name.strip().lower() in _SYSTEM_INTEREST_NAMES,
            "level": activity_type.level if activity_type else None,
            "goal": activity_type.goal if activity_type else None,
            "plan": activity_type._plan_dict() if activity_type else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }

    @property
    def primary_activity_type(self):
        if not self.activity_types:
            return None
        return self.activity_types[0]
