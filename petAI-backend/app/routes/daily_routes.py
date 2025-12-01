from __future__ import annotations

from flask import Blueprint, request

from ..auth import get_current_user_id, token_required
from ..routes import error_response, success_response
from ..services.daily_activity_service import DailyActivityService
from ..models import db

daily_bp = Blueprint("daily", __name__, url_prefix="/daily")


@daily_bp.route("/activities", methods=["GET"])
@token_required
def list_daily_activities():
    user_id = get_current_user_id()
    if not user_id:
        return error_response("user_id is required", 400)
    activities = DailyActivityService.list_today(user_id)
    db.session.commit()
    return success_response(
        "Today's activities",
        {"activities": [activity.to_dict() for activity in activities]},
    )


@daily_bp.route("/activities/complete", methods=["POST"])
@token_required
def complete_daily_activity():
    user_id = get_current_user_id()
    if not user_id:
        return error_response("user_id is required", 400)
    payload = request.get_json(silent=True) or {}
    activity_id = payload.get("activity_id")
    try:
        activity_id = int(activity_id)
    except (TypeError, ValueError):
        return error_response("activity_id is required", 400)

    try:
        result = DailyActivityService.complete_daily_activity(user_id, activity_id)
        db.session.commit()
    except LookupError as exc:
        db.session.rollback()
        return error_response(str(exc), 404)
    except ValueError as exc:
        db.session.rollback()
        return error_response(str(exc), 400)

    return success_response("Activity completed", result, 201)
