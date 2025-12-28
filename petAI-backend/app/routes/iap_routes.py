from __future__ import annotations

from flask import Blueprint, current_app, request

from ..auth import get_current_user_id, token_required
from ..routes import error_response, success_response
from ..services.subscription_service import SubscriptionService


iap_bp = Blueprint("iap", __name__, url_prefix="/iap")


@iap_bp.route("/status", methods=["GET"])
@token_required
def subscription_status():
    user_id = get_current_user_id()
    if not user_id:
        return error_response("user_id is required", 400)
    payload = SubscriptionService.subscription_payload(user_id)
    return success_response("Subscription status", payload)


@iap_bp.route("/mock", methods=["POST"])
@token_required
def mock_subscription():
    if not current_app.config.get("ENABLE_MOCK_IAP", False):
        return error_response("Mock IAP disabled", 403)
    user_id = get_current_user_id()
    if not user_id:
        return error_response("user_id is required", 400)
    payload = request.get_json(silent=True) or {}
    active = payload.get("active")
    if active is None:
        return error_response("active is required", 400)
    active = bool(active)
    sub = SubscriptionService.set_mock_subscription(user_id, active=active)
    return success_response("Mock subscription updated", {"subscription": sub.to_dict()})
