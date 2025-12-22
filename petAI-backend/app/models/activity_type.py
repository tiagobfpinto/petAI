from __future__ import annotations

from datetime import datetime, timezone

from . import db


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class ActivityType(db.Model):
    __tablename__ = "activity_types"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    interest_id = db.Column(db.Integer, db.ForeignKey("areas.id", ondelete="CASCADE"), nullable=False, index=True)
    name = db.Column(db.String(120), nullable=False)
    description = db.Column(db.String(255))
    level = db.Column(db.String(32), nullable=False, default="sometimes")
    goal = db.Column(db.String(255))
    weekly_goal_value = db.Column(db.Float)
    weekly_goal_unit = db.Column(db.String(32))
    weekly_schedule = db.Column(db.String(255))
    rrule = db.Column(db.String(255))
    created_at = db.Column(db.DateTime(timezone=True), default=_utcnow, nullable=False)
    updated_at = db.Column(db.DateTime(timezone=True), default=_utcnow, onupdate=_utcnow, nullable=False)
    area = db.relationship("Area", back_populates="activity_types")

    __table_args__ = (
        db.UniqueConstraint("user_id", "interest_id", "name", name="uq_user_interest_activity_type"),
    )

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "user_id": self.user_id,
            "interest_id": self.interest_id,
            "name": self.name,
            "description": self.description,
            "level": self.level,
            "goal": self.goal,
            "plan": self._plan_dict(),
            "rrule": self.rrule,
        }

    @property
    def interest(self):
        # Backwards compatibility
        return self.area

    def _plan_dict(self) -> dict | None:
        if (
            self.weekly_goal_value is None
            or self.weekly_goal_value <= 0
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
