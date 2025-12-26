from flask_bcrypt import Bcrypt
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()
bcrypt = Bcrypt()

# Import models for Alembic autogeneration
from .user import User  # noqa: E402,F401
from .pet import Pet  # noqa: E402,F401
from .areas import Area  # noqa: E402,F401
from .interest import Interest  # noqa: E402,F401
from .activity import ActivityLog  # noqa: E402,F401
from .activity_type import ActivityType  # noqa: E402,F401
from .goal import Goal  # noqa: E402,F401
from .daily_activity import DailyActivity  # noqa: E402,F401
from .auth_token import AuthToken  # noqa: E402,F401
from .friend_request import FriendRequest  # noqa: E402,F401
from .item import Item  # noqa: E402,F401
from .itemOwnership import ItemOwnership  # noqa: E402,F401
from .itemTransaction import ItemTransaction  # noqa: E402,F401
from .storeListing import StoreListing  # noqa: E402,F401
from .admin_user import Admin_Users  # noqa: E402,F401
from .petStyle import PetStyle  # noqa: E402,F401
from .milestone_redemption import MilestoneRedemption  # noqa: E402,F401

__all__ = [
    "db",
    "bcrypt",
    "User",
    "Pet",
    "Area",
    "Interest",
    "ActivityLog",
    "ActivityType",
    "Goal",
    "DailyActivity",
    "AuthToken",
    "FriendRequest",
    "Item","ItemOwnership",
    "ItemTransaction","StoreListing","Admin_Users","PetStyle",
    "MilestoneRedemption",
]
