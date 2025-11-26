from __future__ import annotations

from ..models import db
from ..models.pet import Pet


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
