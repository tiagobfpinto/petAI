from __future__ import annotations

from flask import Blueprint, request

from ..auth import active_user_required, get_current_user_id, token_required
from ..models import db
from ..routes import error_response, success_response
from ..services.activity_service import ActivityService


activity_bp = Blueprint("activities", __name__, url_prefix="/activities")


def _resolve_user_id() -> int | None:
    user_id = get_current_user_id()
    if user_id:
        return user_id
    return request.args.get("user_id", type=int)


@activity_bp.route("/complete", methods=["POST"])
@token_required
@active_user_required
def complete_activity():
    payload = request.get_json(silent=True) or {}
    interest_name = (payload.get("interest") or "").strip()
    user_id = _resolve_user_id()

    if not user_id:
        return error_response("user_id is required", 400)

    if not interest_name:
        return error_response("interest is required", 400)

    try:
        result = ActivityService.complete_activity(user_id, interest_name)
        db.session.commit()
    except LookupError as exc:
        db.session.rollback()
        return error_response(str(exc), 404)
    except ValueError as exc:
        db.session.rollback()
        return error_response(str(exc), 400)

    pet = result["pet"].to_dict()
    activity = result["activity"].to_dict()

    return success_response(
        "Activity completed",
        {
            "xp": pet["xp"],
            "level": pet["level"],
            "stage": pet["stage"],
            "evolved": result["evolved"],
            "pet": pet,
            "xp_awarded": result["xp_awarded"],
            "interest_id": result.get("interest_id"),
            "activity": activity,
        },
        201,
    )


@activity_bp.route("/today", methods=["GET"])
@token_required
def today_activities():
    user_id = _resolve_user_id()
    if not user_id:
        return error_response("user_id is required", 400)

    activities = ActivityService.today_activities(user_id)
    return success_response(
        "Today's activities",
        {"activities": [activity.to_dict() for activity in activities]},
    )
