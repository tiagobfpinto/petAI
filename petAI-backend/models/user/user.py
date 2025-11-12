from flask_login import UserMixin
from datetime import datetime, timezone
from enum import Enum
from sqlalchemy import Enum as PgEnum
from models import db, bcrypt  # ✅ import from models package

class PlanType(Enum):
    PREMIUM = "PREMIUM"
    FREE_TRIAL = "FREE_TRIAL"
    FREE = "FREE"

class User(UserMixin, db.Model):
    __tablename__ = "users"

    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(50), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(128), nullable=False)
    full_name = db.Column(db.String(120))
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
    plan = db.Column(PgEnum(PlanType, name="plan_type_enum"), default=PlanType.FREE, nullable=False)

    def set_password(self, password):
        self.password_hash = bcrypt.generate_password_hash(password).decode("utf-8")

    def check_password(self, password):
        return bcrypt.check_password_hash(self.password_hash, password)
