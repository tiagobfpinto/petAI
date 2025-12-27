from __future__ import annotations

from flask import Blueprint

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
