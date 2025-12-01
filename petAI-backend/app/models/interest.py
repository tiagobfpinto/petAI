from __future__ import annotations

from datetime import datetime, timezone

from . import db


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Interest(db.Model):
    __tablename__ = "interests"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    name = db.Column(db.String(120), nullable=False)
    level = db.Column(db.String(32), nullable=False)
    goal = db.Column(db.String(255))
    weekly_goal_value = db.Column(db.Float)
    weekly_goal_unit = db.Column(db.String(32))
    weekly_schedule = db.Column(db.String(255))
    created_at = db.Column(db.DateTime(timezone=True), default=_utcnow, nullable=False)
    updated_at = db.Column(db.DateTime(timezone=True), default=_utcnow, onupdate=_utcnow, nullable=False)

    user = db.relationship("User", back_populates="interests")

    __table_args__ = (
        db.UniqueConstraint("user_id", "name", name="uq_user_interest_name"),
    )

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "user_id": self.user_id,
            "name": self.name,
            "level": self.level,
            "goal": self.goal,
            "plan": self._plan_dict(),
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }

    def _plan_dict(self) -> dict | None:
        if (
            self.weekly_goal_value is None
            or self.weekly_goal_unit is None
            or not self.weekly_schedule
        ):
            return None
        days = [day for day in self.weekly_schedule.split(",") if day]
        per_day = None
        if days:
            per_day = round(float(self.weekly_goal_value) / len(days), 2)
        return {
            "weekly_goal_value": self.weekly_goal_value,
            "weekly_goal_unit": self.weekly_goal_unit,
            "days": days,
            "per_day_goal_value": per_day,
        }
