from __future__ import annotations

from datetime import datetime, timezone

from . import db


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Goal(db.Model):
    __tablename__ = "goals"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    activity_type_id = db.Column(db.Integer, db.ForeignKey("activity_types.id", ondelete="CASCADE"), nullable=False)
    title = db.Column(db.String(255))
    amount = db.Column(db.Float)
    unit = db.Column(db.String(32))
    progress_value = db.Column(db.Float, default=0)
    expires_at = db.Column(db.DateTime(timezone=True), nullable=False)
    created_at = db.Column(db.DateTime(timezone=True), default=_utcnow, nullable=False)
    updated_at = db.Column(db.DateTime(timezone=True), default=_utcnow, onupdate=_utcnow, nullable=False)

    activity_type = db.relationship("ActivityType")

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "user_id": self.user_id,
            "activity_type_id": self.activity_type_id,
            "title": self.title,
            "amount": self.amount,
            "unit": self.unit,
            "progress_value": self.progress_value,
            "expires_at": self.expires_at.isoformat() if self.expires_at else None,
        }
