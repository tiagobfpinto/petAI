from __future__ import annotations

from flask import Blueprint, request

from ..auth import get_current_user_id, token_required
from ..models import db
from ..routes import error_response, success_response
from ..services.hub_service import HubService
from ..services.friend_service import FriendService


hub_bp = Blueprint("hub", __name__, url_prefix="/hub")


@hub_bp.route("/shop", methods=["GET"])
@token_required
def get_shop_state():
    user_id = get_current_user_id()
    if not user_id:
        return error_response("user_id is required", 400)
    state = HubService.shop_state(user_id)
    db.session.commit()
    return success_response("Shop ready", state)


@hub_bp.route("/shop/purchase", methods=["POST"])
@token_required
def purchase_item():
    user_id = get_current_user_id()
    if not user_id:
        return error_response("user_id is required", 400)
    payload = request.get_json(silent=True) or {}
    item_id = (payload.get("item_id") or "").strip()
    if not item_id:
        return error_response("item_id is required", 400)

    try:
        state = HubService.purchase_item(user_id, item_id)
        db.session.commit()
    except LookupError as exc:
        db.session.rollback()
        return error_response(str(exc), 404)
    except ValueError as exc:
        db.session.rollback()
        return error_response(str(exc), 400)

    return success_response("Purchase completed", state, 201)


@hub_bp.route("/friends", methods=["GET"])
@token_required
def friends_feed():
    user_id = get_current_user_id()
    if not user_id:
        return error_response("user_id is required", 400)
    friends = FriendService.friends_payload(user_id)
    db.session.commit()
    return success_response("Friend feed", friends)


@hub_bp.route("/progression", methods=["GET"])
@token_required
def progression():
    user_id = get_current_user_id()
    if not user_id:
        return error_response("user_id is required", 400)
    try:
        snapshot = HubService.progression_snapshot(user_id)
    except LookupError as exc:
        return error_response(str(exc), 404)
    db.session.commit()
    return success_response("Progression snapshot", snapshot)
