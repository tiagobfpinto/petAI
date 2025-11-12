from datetime import datetime, timezone
from models import db  # ✅ import db from models package

class Interest(db.Model):
    __tablename__ = "interests"

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(64), unique=True, nullable=False)
    description = db.Column(db.String(255))
    category = db.Column(db.String(64))
    icon = db.Column(db.String(128))
    suggested_goals = db.Column(db.JSON, default={})
    suggested_activities = db.Column(db.JSON, default=[])
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
