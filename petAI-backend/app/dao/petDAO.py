from __future__ import annotations

from ..models import db
from ..models.pet import Pet
from ..models.petStyle import PetStyle

class PetDAO:
    @staticmethod
    def create_for_user(user_id: int) -> Pet:
        pet = Pet(user_id=user_id)
        db.session.add(pet)
        return pet

    @staticmethod
    def get_by_user_id(user_id: int) -> Pet | None:
        return Pet.query.filter_by(user_id=user_id).first()

    @staticmethod
    def save(pet: Pet) -> Pet:
        db.session.add(pet)
        return pet

    @staticmethod
    def delete_for_user(user_id: int) -> None:
        Pet.query.filter_by(user_id=user_id).delete(synchronize_session=False)
        
    @staticmethod
    def get_pet_style(pet_id: int) -> list[int]:
        return PetStyle.query.filter_by(pet_id=pet_id).first()

    @staticmethod
    def create_new_pet_style(pet_id: int, item_id: int) -> PetStyle:
        if not pet_id or not item_id:
            raise ValueError("pet_id and item_id are required")
        if PetDAO.get_pet_style(pet_id):
            raise ValueError("PetStyle already exists for this pet_id")
        
        pet_style = PetStyle(pet_id=pet_id, equipped_item_id=item_id)
        db.session.add(pet_style)
        db.session.commit()
        return pet_style