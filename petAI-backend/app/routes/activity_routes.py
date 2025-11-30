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
    amount_raw = payload.get("amount")
    amount: float | None = None
    if amount_raw is not None:
        try:
            amount = float(amount_raw)
        except (TypeError, ValueError):
            return error_response("amount must be a number", 400)
        if amount <= 0:
            return error_response("amount must be greater than zero", 400)
    user_id = _resolve_user_id()

    if not user_id:
        return error_response("user_id is required", 400)

    if not interest_name:
        return error_response("interest is required", 400)

    try:
        result = ActivityService.complete_activity(user_id, interest_name, amount=amount)
        db.session.commit()
    except LookupError as exc:
        db.session.rollback()
        return error_response(str(exc), 404)
    except ValueError as exc:
        db.session.rollback()
        return error_response(str(exc), 400)

    pet_obj = result["pet"]
    pet = result.get("pet_dict") or (pet_obj.to_dict() if hasattr(pet_obj, "to_dict") else {})
    activity = result["activity"].to_dict()
    goal_rewards = result.get("goal_rewards") or {}

    return success_response(
        "Activity completed",
        {
            "xp": pet["xp"],
            "level": pet["level"],
            "stage": pet["stage"],
            "evolved": result["evolved"],
            "pet": pet,
            "xp_awarded": result["xp_awarded"],
            "base_xp": result.get("base_xp"),
            "bonus_xp": result.get("bonus_xp"),
            "interest_id": result.get("interest_id"),
            "activity": activity,
            "streak_current": result.get("streak_current"),
            "streak_best": result.get("streak_best"),
            "xp_multiplier": result.get("xp_multiplier"),
            "goal_rewards": goal_rewards,
            "goal_suggestions": goal_rewards.get("suggestions"),
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
