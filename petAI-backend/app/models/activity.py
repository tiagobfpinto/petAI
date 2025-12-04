from __future__ import annotations

from datetime import datetime, timezone

from . import db


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class ActivityLog(db.Model):
    __tablename__ = "activity_logs"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    interest_id = db.Column(db.Integer, db.ForeignKey("areas.id", ondelete="CASCADE"), nullable=False)
    activity_name = db.Column(db.String(255))
    timestamp = db.Column(db.DateTime(timezone=True), default=_utcnow, nullable=False)
    xp_earned = db.Column(db.Integer, nullable=False)

    user = db.relationship("User", back_populates="activities")
    area = db.relationship("Area")

    @property
    def interest_name(self) -> str | None:
        return self.area.name if self.area else None

    @property
    def activity_title(self) -> str | None:
        """Best-effort description of what the user did."""
        if getattr(self, "_activity_override", None):
            return self._activity_override
        # Stored title takes precedence if available.
        if self.activity_name:
            return self.activity_name
        if self.area and getattr(self.area, "primary_activity_type", None):
            activity_type = self.area.primary_activity_type
            if activity_type and activity_type.goal:
                return activity_type.goal
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
