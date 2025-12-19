from __future__ import annotations

from flask import Blueprint, request

from ..auth import get_current_user_id, token_required
from ..models import db
from ..routes import error_response, success_response
from ..services.friend_service import FriendService


friends_bp = Blueprint("friends", __name__, url_prefix="/friends")


@friends_bp.route("", methods=["GET"])
@token_required
def list_friends():
    user_id = get_current_user_id()
    if not user_id:
        return error_response("user_id is required", 400)
    payload = FriendService.friends_payload(user_id)
    db.session.commit()
    return success_response("Friends overview", payload)


@friends_bp.route("/request", methods=["POST"])
@token_required
def send_request():
    user_id = get_current_user_id()
    if not user_id:
        return error_response("user_id is required", 400)
    payload = request.get_json(silent=True) or {}
    username = (payload.get("username") or "").strip()
    if not username:
        return error_response("username is required", 400)
    try:
        fr = FriendService.send_request(user_id, username)
        db.session.commit()
    except LookupError as exc:
        db.session.rollback()
        return error_response(str(exc), 404)
    except ValueError as exc:
        db.session.rollback()
        return error_response(str(exc), 400)
    return success_response(
        "Friend request sent",
        {"request": fr.to_dict()},
        201 if fr.status == "pending" else 200,
    )


@friends_bp.route("/accept", methods=["POST"])
@token_required
def accept_request():
    user_id = get_current_user_id()
    if not user_id:
        return error_response("user_id is required", 400)
    payload = request.get_json(silent=True) or {}
    request_id = payload.get("request_id")
    try:
        request_id = int(request_id)
    except (TypeError, ValueError):
        return error_response("request_id is required", 400)

    try:
        fr = FriendService.accept_request(user_id, request_id)
        db.session.commit()
    except LookupError as exc:
        db.session.rollback()
        return error_response(str(exc), 404)
    except ValueError as exc:
        db.session.rollback()
        return error_response(str(exc), 400)

    return success_response("Friend request accepted", {"request": fr.to_dict()})


@friends_bp.route("/search", methods=["GET"])
@token_required
def search_users():
    user_id = get_current_user_id()
    if not user_id:
        return error_response("user_id is required", 400)
    query = (request.args.get("query") or request.args.get("q") or "").strip()
    if len(query) < 2:
        return success_response("Search results", {"matches": []})
    matches = FriendService.search_users(user_id, query)
    return success_response("Search results", {"matches": matches})


@friends_bp.route("/remove", methods=["POST"])
@token_required
def remove_friend():
    user_id = get_current_user_id()
    if not user_id:
        return error_response("user_id is required", 400)
    payload = request.get_json(silent=True) or {}
    friend_id = payload.get("friend_id")
    try:
        friend_id = int(friend_id)
    except (TypeError, ValueError):
        return error_response("friend_id is required", 400)

    try:
        FriendService.remove_friend(user_id, friend_id)
        db.session.commit()
    except LookupError as exc:
        db.session.rollback()
        return error_response(str(exc), 404)
    except ValueError as exc:
        db.session.rollback()
        return error_response(str(exc), 400)

    return success_response("Friend removed", {})
