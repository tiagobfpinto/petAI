
from sqlalchemy import or_

from models.user.user import User


class UserDAO:
    @staticmethod
    def existing_user(username: str, email: str):
        """Return the first user matching username or email, if any."""
        return User.query.filter(
            or_(User.username == username, User.email == email)
        ).first()
