
from models import db
from models.pet.pet import Pet


class PetService:
    @staticmethod
    def create_pet(user_id):
        """
        Creates a new pet for the given user_id.
        One pet per user. If the user already has a pet, raise an error or return existing.
        """

        existing = Pet.query.filter_by(user_id=user_id).first()
        if existing:
            return existing

        pet = Pet(user_id=user_id)
        db.session.add(pet)
        return pet
        
