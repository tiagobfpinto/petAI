from __future__ import annotations

from ..config import PET_EVOLUTIONS
from ..dao.petDAO import PetDAO
from ..models import db
from ..models.pet import Pet


class PetService:
    @staticmethod
    def create_pet(user_id: int) -> Pet:
        existing = PetDAO.get_by_user_id(user_id)
        if existing:
            return existing
        pet = PetDAO.create_for_user(user_id)
        db.session.flush()
        return pet

    @staticmethod
    def get_pet_by_user(user_id: int) -> Pet | None:
        return PetDAO.get_by_user_id(user_id)

    @staticmethod
    def add_xp(pet: Pet, amount: int) -> dict:
        if amount <= 0:
            return {"pet": pet, "evolved": False}

        pet.xp = max(0, (pet.xp or 0) + amount)
        pet_state = PetService.evolve_if_needed(pet)
        PetDAO.save(pet)
        return pet_state

    @staticmethod
    def evolve_if_needed(pet: Pet) -> dict:
        sorted_levels = sorted(PET_EVOLUTIONS.items(), key=lambda item: item[0])
        evolved = False
        new_level = pet.level
        new_stage = pet.stage

        for level, data in sorted_levels:
            if pet.xp >= data["xp_required"]:
                if level != new_level:
                    evolved = True
                new_level = level
                new_stage = data["stage"]

        next_level = new_level + 1
        next_config = PET_EVOLUTIONS.get(next_level)
        pet.level = new_level
        pet.stage = new_stage
        pet.next_evolution_xp = (
            next_config["xp_required"] if next_config else PET_EVOLUTIONS[new_level]["xp_required"]
        )
        return {"pet": pet, "evolved": evolved}

    @staticmethod
    def reset_pet(user_id: int) -> Pet | None:
        pet = PetDAO.get_by_user_id(user_id)
        if not pet:
            return None

        base_config = PET_EVOLUTIONS[1]
        pet.xp = 0
        pet.level = 1
        pet.stage = base_config["stage"]
        pet.next_evolution_xp = PET_EVOLUTIONS[2]["xp_required"]
        PetDAO.save(pet)
        return pet
