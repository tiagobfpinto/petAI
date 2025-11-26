from __future__ import annotations

from flask import Blueprint, request

from ..auth import get_current_user_id, token_required
from ..models import db
from ..routes import error_response, success_response
from ..services.pet_service import PetService


pet_bp = Blueprint("pet", __name__, url_prefix="/pet")


def _resolve_user_id() -> int | None:
    user_id = get_current_user_id()
    if user_id:
        return user_id
    return request.args.get("user_id", type=int)


@pet_bp.route("", methods=["GET"])
@token_required
def get_pet():
    user_id = _resolve_user_id()
    if not user_id:
        return error_response("user_id is required", 400)

    pet = PetService.get_pet_by_user(user_id) or PetService.create_pet(user_id)
    db.session.commit()
    return success_response("Pet state", {"pet": pet.to_dict()})


@pet_bp.route("/reset", methods=["POST"])
@token_required
def reset_pet():
    user_id = _resolve_user_id()
    if not user_id:
        return error_response("user_id is required", 400)

    pet = PetService.reset_pet(user_id)
    if not pet:
        return error_response("Pet not found", 404)
    db.session.commit()
    return success_response("Pet reset", {"pet": pet.to_dict()})


@pet_bp.route("/evolve", methods=["POST"])
@token_required
def evolve_pet():
    user_id = _resolve_user_id()
    if not user_id:
        return error_response("user_id is required", 400)

    pet = PetService.get_pet_by_user(user_id)
    if not pet:
        return error_response("Pet not found", 404)

    result = PetService.evolve_if_needed(pet)
    db.session.commit()
    return success_response(
        "Pet evolution checked",
        {
            "pet": pet.to_dict(),
            "evolved": result["evolved"],
        },
    )
