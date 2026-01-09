from __future__ import annotations

from flask import Blueprint, request

from ..auth import get_current_user_id, token_required
from ..models import db
from ..routes import error_response, success_response
from ..services.access_code_service import AccessCodeService
from ..services.subscription_service import SubscriptionService


access_codes_bp = Blueprint("access_codes", __name__, url_prefix="/access-codes")


@access_codes_bp.route("/redeem", methods=["POST"])
@token_required
def redeem_access_code():
    user_id = get_current_user_id()
    if not user_id:
        return error_response("user_id is required", 400)

    payload = request.get_json(silent=True) or {}
    raw_code = (payload.get("code") or "").strip()
    if not raw_code:
        return error_response("Code not working", 400)

    if SubscriptionService.subscription_payload(user_id).get("active"):
        return error_response("Code not working", 400)

    try:
        redemption = AccessCodeService.redeem_code(user_id, raw_code)
        db.session.commit()
    except ValueError as exc:
        db.session.rollback()
        return error_response(str(exc), 400)
    except LookupError as exc:
        db.session.rollback()
        return error_response(str(exc), 404)

    return success_response(
        "Access code redeemed",
        {
            "access_code": redemption.access_code.to_dict()
            if redemption.access_code
            else None,
            "subscription": SubscriptionService.subscription_payload(user_id),
        },
    )
