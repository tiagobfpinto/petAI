from __future__ import annotations

from flask import Blueprint, request

from ..auth import get_current_user_id, token_required
from ..models import db
from ..routes import error_response, success_response
from ..services.push_service import PushService


push_bp = Blueprint("push", __name__, url_prefix="/push")

_ALLOWED_PLATFORMS = {"ios", "android", "web"}


@push_bp.route("/register", methods=["POST"])
@token_required
def register_token():
    user_id = get_current_user_id()
    if not user_id:
        return error_response("user_id is required", 400)
    payload = request.get_json(silent=True) or {}
    token = (payload.get("token") or "").strip()
    platform = (payload.get("platform") or "").strip().lower()
    device_id = (payload.get("device_id") or "").strip() or None

    if not token or not platform:
        return error_response("token and platform are required", 400)
    if platform not in _ALLOWED_PLATFORMS:
        return error_response("platform must be ios, android, or web", 400)

    entry = PushService.register_token(user_id, token, platform, device_id)
    db.session.commit()
    return success_response("Token registered", {"token": entry.to_dict()}, 201)


@push_bp.route("/unregister", methods=["POST"])
@token_required
def unregister_token():
    user_id = get_current_user_id()
    if not user_id:
        return error_response("user_id is required", 400)
    payload = request.get_json(silent=True) or {}
    token = (payload.get("token") or "").strip()
    if not token:
        return error_response("token is required", 400)

    removed = PushService.unregister_token(user_id, token)
    db.session.commit()
    return success_response("Token removed", {"removed": removed})
