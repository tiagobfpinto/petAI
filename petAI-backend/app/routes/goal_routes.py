from __future__ import annotations

from flask import Blueprint, request

from ..auth import get_current_user_id, token_required
from ..dao.activityDAO import ActivityDAO
from ..dao.interestDAO import InterestDAO
from ..dao.userDAO import UserDAO
from ..routes import error_response, success_response
from ..services.goal_service import GoalService

goal_bp = Blueprint("goal", __name__, url_prefix="/goal")


def _find_running_interest(user_id: int | None):
    if not user_id:
        return None
    interest = InterestDAO.get_by_user_and_name(user_id, "running")
    if interest:
        return interest
    for entry in InterestDAO.list_for_user(user_id):
        name = (entry.name or "").lower()
        if "running" in name or "cardio" in name:
            return entry
    return None


@goal_bp.route("/suggested", methods=["GET"])
@token_required
def suggested_goal():
    user_id = get_current_user_id()
    if not user_id:
        return error_response("user_id is required", 400)

    age = request.args.get("age", type=int)
    gender = (request.args.get("gender") or "").strip() or None
    activity_level = (
        request.args.get("activity_level")
        or request.args.get("level")
        or request.args.get("frequency")
        or ""
    ).strip() or None
    refused_raw = request.args.getlist("refused")
    refused: list[str] = []
    if refused_raw:
        if len(refused_raw) == 1 and "," in refused_raw[0]:
            refused = [item.strip() for item in refused_raw[0].split(",") if item.strip()]
        else:
            refused = [item.strip() for item in refused_raw if item.strip()]

    user = UserDAO.get_by_id(user_id)
    if not user:
        return error_response("User not found", 404)
    if age is None:
        age = user.age
    if age is None:
        return error_response("age is required", 400)
    if gender is None:
        gender = user.gender
    if gender is None:
        return error_response("gender is required", 400)

    running_interest = _find_running_interest(user_id)
    if activity_level is None and running_interest and running_interest.level:
        activity_level = running_interest.level

    recent_names: list[str] = []
    if running_interest:
        for activity in ActivityDAO.list_for_user(user_id):
            if activity.interest_id != running_interest.id:
                continue
            name = getattr(activity, "activity_title", None) or getattr(activity, "interest_name", None)
            if name:
                recent_names.append(name)
            if len(recent_names) >= 5:
                break

    suggestion = GoalService.suggest_cardio_activity(
        age=age,
        gender=gender,
        activity_level=activity_level,
        last_activities=recent_names,
        refused_activities=refused,
    )
    return success_response("Suggested cardio goal", suggestion)


@goal_bp.route("/weekly", methods=["GET"])
@token_required
def weekly_goal():
    user_id = get_current_user_id()
    if not user_id:
        return error_response("user_id is required", 400)

    age = request.args.get("age", type=int)
    gender = (request.args.get("gender") or "").strip() or None
    chosen_activity = (request.args.get("activity") or "").strip() or "running"
    interest_name = (request.args.get("interest") or "running").strip().lower()

    user = UserDAO.get_by_id(user_id)
    if not user:
        return error_response("User not found", 404)
    if age is None:
        age = user.age
    if age is None:
        return error_response("age is required", 400)
    if gender is None:
        gender = user.gender
    if gender is None:
        return error_response("gender is required", 400)

    last_goal_value = request.args.get("last_goal_value", type=float)
    last_goal_unit = (request.args.get("last_goal_unit") or "").strip() or None

    # Try to pull the previous weekly goal from the user's stored plan.
    existing_interest = _find_running_interest(user_id)
    if existing_interest:
        if last_goal_value is None and existing_interest.weekly_goal_value is not None:
            last_goal_value = existing_interest.weekly_goal_value
        if last_goal_unit is None and existing_interest.weekly_goal_unit:
            last_goal_unit = existing_interest.weekly_goal_unit

    suggestion = GoalService.suggest_weekly_goal(
        age=age,
        gender=gender,
        chosen_activity=chosen_activity,
        last_goal_value=last_goal_value,
        last_goal_unit=last_goal_unit,
    )
    return success_response("Suggested weekly goal", suggestion)
