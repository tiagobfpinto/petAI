from __future__ import annotations

from collections import defaultdict

from ..config import PET_EVOLUTIONS
from ..dao.petDAO import PetDAO
from ..models import db
from ..models.pet import Pet
from ..models.petStyle import PetStyle


class PetService:
    _COSMETIC_SLOTS = ("head", "face", "neck", "feet", "back")
    _cosmetic_loadouts: defaultdict[int, dict[str, str]] = defaultdict(dict)

    @staticmethod
    def _ensure_pet_style(pet_id: int | None) -> bool:
        if not pet_id:
            return False
        existing = PetStyle.query.filter_by(pet_id=pet_id).first()
        if existing:
            return False
        db.session.add(PetStyle(pet_id=pet_id))
        return True

    @staticmethod
    def create_pet(user_id: int) -> Pet:
        existing = PetDAO.get_by_user_id(user_id)
        if existing:
            if PetService._ensure_pet_style(existing.id):
                db.session.flush()
            return existing
        pet = PetDAO.create_for_user(user_id)
        db.session.flush()
        if PetService._ensure_pet_style(pet.id):
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

    # --- Cosmetics helpers ---
    @classmethod
    def _normalized_slot(cls, slot: str | None) -> str | None:
        if not slot:
            return None
        normalized = slot.strip().lower()
        return normalized if normalized in cls._COSMETIC_SLOTS else None

    @classmethod
    def cosmetic_loadout(cls, user_id: int) -> dict[str, str]:
        loadout = cls._cosmetic_loadouts.get(user_id) or {}
        # filter out any legacy/invalid slots
        return {
            slot: item_id
            for slot, item_id in loadout.items()
            if slot in cls._COSMETIC_SLOTS and item_id
        }

    @classmethod
    def equip_cosmetic(cls, user_id: int, slot: str, item_id: str) -> dict[str, str]:
        normalized_slot = cls._normalized_slot(slot)
        if not normalized_slot or not item_id:
            return cls.cosmetic_loadout(user_id)
        loadout = cls._cosmetic_loadouts[user_id]
        loadout[normalized_slot] = item_id
        return cls.cosmetic_loadout(user_id)

    @classmethod
    def clear_cosmetics(cls, user_id: int) -> dict[str, str]:
        cls._cosmetic_loadouts.pop(user_id, None)
        return {}

    @classmethod
    def cosmetic_payload(cls, user_id: int) -> dict:
        return {"equipped": cls.cosmetic_loadout(user_id)}

    @classmethod
    def pet_payload(cls, pet: Pet) -> dict:
        payload = pet.to_dict()
        user = getattr(pet, "user", None)
        payload["coins"] = (getattr(user, "coins", 0) or 0) if user else 0
        payload["cosmetics"] = cls.cosmetic_payload(pet.user_id)
        return payload
