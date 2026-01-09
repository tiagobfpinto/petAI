from __future__ import annotations

from flask import Blueprint, request

from ..auth import get_current_user_id, premium_required, token_required
from ..dao.itemsDAO import ItemOwnershipDAO, ItemsDAO
from ..models import db
from ..models.petStyle import PetStyle
from ..routes import error_response, success_response
from ..services.pet_service import PetService


style_bp = Blueprint("style", __name__, url_prefix="/style")


def _resolve_user_id() -> int | None:
    user_id = get_current_user_id()
    if user_id:
        return user_id
    return request.args.get("user_id", type=int)


@style_bp.route("", methods=["GET"])
@token_required
@premium_required
def get_inventory_items():
    user_id = _resolve_user_id()
    if not user_id:
        return error_response("user_id is required", 400)

    owned_items = ItemOwnershipDAO.get_items_owned_by_user(user_id)
    payload: list[dict] = []
    for owned in owned_items:
        item = ItemsDAO.get_item_by_id(owned.item_id)
        if not item:
            continue
        payload.append(
            {
                "ownership_id": owned.id,
                "item_id": item.id,
                "quantity": owned.quantity,
                "name": item.name,
                "description": item.description,
                "type": item.type.value if item.type else None,
                "asset_type": item.asset_type.value if item.asset_type else None,
                "asset_path": item.asset_path,
                "layer_name": item.layer_name,
                "rarity": item.rarity,
                "trigger": item.trigger,
                "trigger_value": item.trigger_value,
            }
        )

    return success_response("User inventory", {"items": payload})


@style_bp.route("/equipped", methods=["GET"])
@token_required
@premium_required
def get_equipped_style():
    user_id = _resolve_user_id()
    if not user_id:
        return error_response("user_id is required", 400)

    pet = PetService.get_pet_by_user(user_id) or PetService.create_pet(user_id)
    db.session.flush()

    pet_style = PetStyle.query.filter_by(pet_id=pet.id).first()
    if not pet_style:
        pet_style = PetStyle(pet_id=pet.id)
        db.session.add(pet_style)
        db.session.flush()

    def _item_payload(item_id: int | None) -> dict | None:
        if not item_id:
            return None
        item = ItemsDAO.get_item_by_id(item_id)
        if not item:
            return {"item_id": item_id, "trigger": None, "trigger_value": None, "missing": True}
        return {
            "item_id": item.id,
            "name": item.name,
            "type": item.type.value if item.type else None,
            "trigger": item.trigger,
            "trigger_value": item.trigger_value,
        }

    payload = {
        "style": pet_style.to_dict(),
        "equipped": {
            "hat": _item_payload(pet_style.hat_id),
            "sunglasses": _item_payload(pet_style.sunglasses_id),
            "color": _item_payload(pet_style.color_id),
            "background": _item_payload(pet_style.background_id),
        },
    }

    db.session.commit()
    return success_response("Equipped style", payload)


@style_bp.route("/equip/<int:item_id>", methods=["POST"])
@token_required
@premium_required
def equip_item(item_id: int):
    user_id = _resolve_user_id()
    if not user_id:
        return error_response("user_id is required", 400)

    owned = ItemOwnershipDAO.get_item_from_inventory(user_id, item_id)
    if not owned or (owned.quantity or 0) <= 0:
        return error_response("Item not owned", 404)

    item = ItemsDAO.get_item_by_id(item_id)
    if not item:
        return error_response("Item not found", 404)

    pet = PetService.get_pet_by_user(user_id) or PetService.create_pet(user_id)
    db.session.flush()

    pet_style = PetStyle.query.filter_by(pet_id=pet.id).first()
    if not pet_style:
        pet_style = PetStyle(pet_id=pet.id)
        db.session.add(pet_style)
        db.session.flush()

    item_type_raw = (item.type.value if item.type else "").strip()
    item_type = item_type_raw.lower()
    equipped_slot: str | None = None
    if item_type in ("hat", "headwear", "head"):
        pet_style.hat_id = item.id
        equipped_slot = "hat"
    elif item_type in ("sunglasses", "glasses", "shade", "shades", "face", "sunglass"):
        pet_style.sunglasses_id = item.id
        equipped_slot = "sunglasses"
    elif item_type in ("color", "colour"):
        pet_style.color_id = item.id
        equipped_slot = "color"
    elif item_type in ("background", "bg", "backdrop"):
        pet_style.background_id = item.id
        equipped_slot = "background"
    else:
        # Handle enum-ish values stored as strings (e.g. "HAT", "SUNGLASSES", "COLOR")
        enum_like = item_type_raw.upper()
        if enum_like == "HAT":
            pet_style.hat_id = item.id
            equipped_slot = "hat"
        elif enum_like in ("SUNGLASSES", "GLASSES"):
            pet_style.sunglasses_id = item.id
            equipped_slot = "sunglasses"
        elif enum_like == "COLOR":
            pet_style.color_id = item.id
            equipped_slot = "color"
        elif enum_like == "BACKGROUND":
            pet_style.background_id = item.id
            equipped_slot = "background"
        else:
            return error_response("Item type cannot be equipped", 400)

    db.session.commit()

    return success_response(
        "Item equipped",
        {
            "style": pet_style.to_dict(),
            "equipped": {
                "slot": equipped_slot,
                "item_id": item.id,
                "trigger": item.trigger,
                "trigger_value": item.trigger_value,
            },
        },
    )

    
