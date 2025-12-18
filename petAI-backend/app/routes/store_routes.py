from __future__ import annotations

from flask import Blueprint, request

from ..auth import get_current_user_id, token_required
from ..dao.itemsDAO import ItemOwnershipDAO, ItemsDAO, StoreListingDAO
from ..dao.userDAO import UserDAO
from ..models import db
from ..routes import error_response, success_response
from ..services.pet_service import PetService

store_bp = Blueprint("store", __name__, url_prefix="/store")


def _resolve_user_id() -> int | None:
    user_id = get_current_user_id()
    if user_id:
        return user_id
    return request.args.get("user_id", type=int)


@store_bp.route("", methods=["GET"])
@token_required
def get_store_listings():
    user_id = _resolve_user_id()
    owned_by_item_id: dict[int, int] = {}
    if user_id:
        owned_items = ItemOwnershipDAO.get_items_owned_by_user(user_id)
        owned_by_item_id = {
            owned.item_id: (owned.quantity or 0) for owned in owned_items if owned.item_id is not None
        }

    listings = ItemsDAO.get_all_store_listings()

    payload: list[dict] = []
    for listing in listings:
        item = ItemsDAO.get_item_by_id(listing.item_id)
        if not item:
            continue
        owned_quantity = owned_by_item_id.get(item.id, 0)
        max_quantity = item.max_quantity
        is_maxed = max_quantity is not None and owned_quantity >= max_quantity
        payload.append(
            {
                "id": listing.id,
                "price": listing.price,
                "stock": listing.stock,
                "currency": listing.currency,
                "owned_quantity": owned_quantity,
                "is_maxed": is_maxed,
                "item": {
                    "id": item.id,
                    "name": item.name,
                    "description": item.description,
                    "type": item.type.value if item.type else None,
                    "asset_type": item.asset_type.value if item.asset_type else None,
                    "asset_path": item.asset_path,
                    "layer_name": item.layer_name,
                    "rarity": item.rarity,
                    "trigger": item.trigger,
                    "max_quantity": item.max_quantity,
                },
            }
        )
    return success_response("Store listings", {"listings": payload})


@store_bp.route("/buy/<int:store_listing_id>", methods=["POST"])
@token_required
def buy_item(store_listing_id: int):
    data = request.get_json(silent=True) or {}

    user_id = _resolve_user_id() or data.get("user_id")
    if not user_id:
        return error_response("user_id is required", 400)

    quantity_raw = data.get("quantity", 1)
    try:
        quantity = int(quantity_raw)
    except (TypeError, ValueError):
        return error_response("quantity must be an integer", 400)
    if quantity <= 0:
        return error_response("quantity must be greater than zero", 400)

    store_listing = StoreListingDAO.get_store_listing_by_id(store_listing_id)
    if not store_listing or not store_listing.active:
        return error_response("Store listing not found", 404)

    if store_listing.stock is not None and store_listing.stock < quantity:
        return error_response("Insufficient stock", 400)

    item = ItemsDAO.get_item_by_id(store_listing.item_id)
    if not item:
        return error_response("Item not found", 404)

    user = UserDAO.get_by_id(user_id)
    if not user:
        return error_response("User not found", 404)

    # Ensure pet exists so item ownership has pet_id.
    pet = user.pet or PetService.create_pet(user_id)
    db.session.flush()

    item_owned = ItemOwnershipDAO.get_item_from_inventory(user_id, item.id)
    max_quantity = item.max_quantity
    if max_quantity is not None:
        current_qty = (item_owned.quantity if item_owned else 0) or 0
        if current_qty + quantity > max_quantity:
            return error_response("Already have max items", 400)

    price_to_pay = quantity * (store_listing.price or 0)
    user_coins = user.coins or 0
    if user_coins < price_to_pay:
        return error_response("Insufficient coins", 400)

    user.coins = user_coins - price_to_pay

    if store_listing.stock is not None:
        store_listing.stock -= quantity
        if store_listing.stock <= 0:
            store_listing.stock = 0
            store_listing.active = False

    if item_owned:
        item_owned.quantity = (item_owned.quantity or 0) + quantity
    else:
        ItemOwnershipDAO.create_item_ownership(user_id, item.id, pet.id, quantity)

    db.session.commit()

    return success_response(
        "Item purchased successfully",
        {
            "listing_id": store_listing.id,
            "item_id": item.id,
            "quantity": quantity,
            "remaining_coins": user.coins,
            "stock_remaining": store_listing.stock,
        },
    )
