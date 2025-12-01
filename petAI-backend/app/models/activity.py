from __future__ import annotations

from datetime import datetime, timezone

from . import db


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class ActivityLog(db.Model):
    __tablename__ = "activity_logs"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    interest_id = db.Column(db.Integer, db.ForeignKey("interests.id", ondelete="CASCADE"), nullable=False)
    timestamp = db.Column(db.DateTime(timezone=True), default=_utcnow, nullable=False)
    xp_earned = db.Column(db.Integer, nullable=False)

    user = db.relationship("User", back_populates="activities")
    interest = db.relationship("Interest")

    @property
    def interest_name(self) -> str | None:
        return self.interest.name if self.interest else None

    @property
    def activity_title(self) -> str | None:
        """Best-effort description of what the user did."""
        if self.interest and getattr(self.interest, "goal", None):
            return self.interest.goal
        return self.interest_name

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "user_id": self.user_id,
            "interest_id": self.interest_id,
            "interest": self.interest_name,
            "activity": self.activity_title,
            "timestamp": self.timestamp.isoformat() if self.timestamp else None,
            "xp_earned": self.xp_earned,
        }
