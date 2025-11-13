from models import db
from models.user.user import User
from services.pet.pet_service import PetService


class UserService:
    @staticmethod
    def init_user(
        username: str,
        email: str,
        full_name: str | None,
        password: str,
    ):
        """
        Create a user along with the default pet, ensuring both are staged in the session.
        """
        user = User(username=username, email=email, full_name=full_name)
        user.set_password(password)
        db.session.add(user)
        db.session.flush()  # guarantee user.id for pet FK

        pet = PetService.create_pet(user.id)
        return user, pet
