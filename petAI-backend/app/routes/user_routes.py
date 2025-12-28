from __future__ import annotations

from flask import Blueprint, request

from ..auth import get_current_user_id, premium_required, token_required
from ..dao.userDAO import UserDAO
from ..models import db
from ..routes import error_response, success_response
from ..services.interest_service import InterestService
from ..services.user_service import UserService


user_bp = Blueprint("user_api", __name__, url_prefix="/user")
interests_bp = Blueprint("interests_api", __name__, url_prefix="/interests")


def _resolve_user_id(payload: dict | None = None) -> int | None:
    user_id = get_current_user_id()
    if user_id:
        return user_id
    if payload and payload.get("user_id"):
        try:
            return int(payload["user_id"])
        except (TypeError, ValueError):
            return None
    return request.args.get("user_id", type=int)


@interests_bp.route("", methods=["GET"], strict_slashes=False)
@interests_bp.route("/", methods=["GET"], strict_slashes=False)
@interests_bp.route("/defaults", methods=["GET"], strict_slashes=False)
def get_default_interests():
    return success_response(
        "Default interests",
        {"interests": InterestService.default_interests()},
    )


@user_bp.route("/interests", methods=["GET"])
@token_required
@premium_required
def get_user_interests():
    user_id = _resolve_user_id()
    if not user_id:
        return error_response("user_id is required", 400)

    user = UserDAO.get_by_id(user_id)
    if not user:
        return error_response("User not found", 404)

    interests = InterestService.list_user_interests(user_id)
    return success_response(
        "User interests",
        {
            "interests": [interest.to_dict() for interest in interests],
            "need_interests_setup": len(interests) == 0,
        },
    )


def _persist_interests(user_id: int, entries: list[dict]):
    if not user_id:
        return error_response("user_id is required", 400)

    if entries is None:
        return error_response("interests payload is required", 400)

    try:
        saved_interests = UserService.save_user_interests(user_id, entries)
        db.session.commit()
    except ValueError as exc:
        db.session.rollback()
        return error_response(str(exc), 400)
    except LookupError as exc:
        db.session.rollback()
        return error_response(str(exc), 404)

    return success_response(
        "Interests saved",
        {
            "interests": saved_interests,
            "need_interests_setup": False,
        },
        201,
    )


@user_bp.route("/interests", methods=["POST"])
@token_required
@premium_required
def save_user_interests():
    payload = request.get_json(silent=True) or {}
    user_id = _resolve_user_id(payload)
    entries = payload.get("interests")
    return _persist_interests(user_id, entries)


@user_bp.route("/profile", methods=["POST"])
@token_required
@premium_required
def update_profile():
    payload = request.get_json(silent=True) or {}
    user_id = _resolve_user_id(payload)
    if not user_id:
        return error_response("user_id is required", 400)
    age = payload.get("age")
    gender = payload.get("gender")
    try:
        age_value = int(age) if age is not None else None
    except (TypeError, ValueError):
        return error_response("age must be a number", 400)

    try:
        user_dict = UserService.update_profile(user_id, age=age_value, gender=gender)
        db.session.commit()
    except ValueError as exc:
        db.session.rollback()
        return error_response(str(exc), 400)
    except LookupError as exc:
        db.session.rollback()
        return error_response(str(exc), 404)

    return success_response("Profile updated", {"user": user_dict})


@interests_bp.route("", methods=["POST"])
@interests_bp.route("/", methods=["POST"])
@token_required
@premium_required
def legacy_save_interests():
    """Backwards-compatible alias for POST /user/interests."""
    payload = request.get_json(silent=True) or {}
    user_id = _resolve_user_id(payload)
    if user_id is None:
        user_id = request.args.get("user_id", type=int)
    entries = payload.get("interests")
    return _persist_interests(user_id, entries)
