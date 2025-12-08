from __future__ import annotations

from flask import Blueprint, request

from ..auth import active_user_required, get_current_user_id, token_required
from ..models import db
from ..routes import error_response, success_response
from ..services.activity_service import ActivityService
from ..dao.areaDAO import AreaDAO


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
    area_name = (payload.get("area") or "").strip()
    value = payload.get("value") if payload.get("value") is not None else payload.get("amount")
    unit = (payload.get("unit") or "").strip() or None
    user_id = _resolve_user_id()

    if not user_id:
        return error_response("user_id is required", 400)

    if not area_name:
        return error_response("area is required", 400)

    try:
        result = ActivityService.complete_activity(
            user_id,
            area_name,
            effort_value=value if value is None else float(value),
            effort_unit=unit,
        )
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
            "coins_awarded": result.get("coins_awarded"),
            "interest_id": result.get("interest_id"),
            "activity": activity,
            "streak_current": result.get("streak_current"),
            "streak_best": result.get("streak_best"),
            "xp_multiplier": result.get("xp_multiplier"),
        },
        201,
    )


@activity_bp.route("", methods=["POST"])
@token_required
@active_user_required
def create_activity():
    payload = request.get_json(silent=True) or {}
    user_id = _resolve_user_id()
    if not user_id:
        return error_response("user_id is required", 400)

    activity_name = (payload.get("name") or "").strip()
    area_name = (payload.get("area") or payload.get("interest") or "").strip()
    weekly_goal_value = payload.get("weekly_goal_value")
    weekly_goal_unit = (payload.get("weekly_goal_unit") or "").strip() or None
    days = payload.get("days") if isinstance(payload.get("days"), list) else None
    rrule = (payload.get("rrule") or "").strip() or None

    if not activity_name:
        return error_response("activity name is required", 400)
    if not area_name:
        return error_response("area is required", 400)

    try:
        result = ActivityService.create_activity(
            user_id=user_id,
            interest_name=area_name,
            activity_name=activity_name,
            weekly_goal_value=weekly_goal_value,
            weekly_goal_unit=weekly_goal_unit,
            days=days,
            rrule=rrule,
        )
        db.session.commit()
    except LookupError as exc:
        db.session.rollback()
        return error_response(str(exc), 404)
    except ValueError as exc:
        db.session.rollback()
        return error_response(str(exc), 400)

    return success_response("Activity created", result, 201)


@activity_bp.route("/interest/<int:interest_id>", methods=["POST"])
@token_required
@active_user_required
def create_activity_for_interest(interest_id: int):
    payload = request.get_json(silent=True) or {}
    user_id = _resolve_user_id()
    if not user_id:
        return error_response("user_id is required", 400)

    activity_name = (payload.get("name") or "").strip()
    weekly_goal_value = payload.get("weekly_goal_value")
    weekly_goal_unit = (payload.get("weekly_goal_unit") or "").strip() or None

    if not activity_name:
        return error_response("activity name is required", 400)

    if not InterestDAO.get_by_user_and_id(user_id, interest_id):
        return error_response("Interest not found for user", 404)

    try:
        result = ActivityService.create_activity(
          user_id=user_id,
          activity_name=activity_name,
          interest_id=interest_id,
          weekly_goal_value=weekly_goal_value,
          weekly_goal_unit=weekly_goal_unit,
        )
        db.session.commit()
    except LookupError as exc:
        db.session.rollback()
        return error_response(str(exc), 404)
    except ValueError as exc:
        db.session.rollback()
        return error_response(str(exc), 400)

    return success_response("Activity created", result, 201)


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
