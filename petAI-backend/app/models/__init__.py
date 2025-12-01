from flask_bcrypt import Bcrypt
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()
bcrypt = Bcrypt()

# Import models for Alembic autogeneration
from .user import User  # noqa: E402,F401
from .pet import Pet  # noqa: E402,F401
from .interest import Interest  # noqa: E402,F401
from .activity import ActivityLog  # noqa: E402,F401
from .activity_type import ActivityType  # noqa: E402,F401
from .goal import Goal  # noqa: E402,F401
from .daily_activity import DailyActivity  # noqa: E402,F401
from .auth_token import AuthToken  # noqa: E402,F401
from .friend_request import FriendRequest  # noqa: E402,F401

__all__ = [
    "db",
    "bcrypt",
    "User",
    "Pet",
    "Interest",
    "ActivityLog",
    "ActivityType",
    "Goal",
    "DailyActivity",
    "AuthToken",
    "FriendRequest",
]
