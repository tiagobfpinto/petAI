import pytest

from app import create_app
from app.config import Config
from app.dao.activity_typeDAO import ActivityTypeDAO
from app.dao.areaDAO import AreaDAO
from app.dao.goalDAO import GoalDAO
from app.models import db
from app.services.activity_service import ActivityService
from app.services.daily_activity_service import DailyActivityService
from app.services.user_service import UserService


class TestConfig(Config):
    SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
    TESTING = True


@pytest.fixture()
def app():
    app = create_app(TestConfig)
    with app.app_context():
        db.create_all()
        yield app
        db.session.remove()
        db.drop_all()


@pytest.fixture()
def ctx(app):
    with app.app_context():
        yield


def _seed_running_goal(user_id: int):
    UserService.save_user_interests(
        user_id,
        [
            {
                "name": "Running",
                "level": "sometimes",
                "plan": {
                    "weekly_goal_value": 20,
                    "weekly_goal_unit": "km",
                    "days": ["mon", "tue", "wed", "thu", "fri", "sat", "sun"],
                },
            }
        ],
    )
    db.session.commit()

    area = AreaDAO.get_by_user_and_name(user_id, "Running")
    assert area is not None
    activity_type = ActivityTypeDAO.primary_for_area(user_id, area.id)
    assert activity_type is not None
    goal = GoalDAO.latest_active(user_id, activity_type.id)
    assert goal is not None
    return area, activity_type


def test_area_completions_accumulate_goal_progress(ctx):
    user = UserService.create_guest_user()
    db.session.commit()

    _, activity_type = _seed_running_goal(user.id)

    ActivityService.complete_activity(
        user.id,
        "Running",
        effort_value=5,
        effort_unit="km",
    )
    ActivityService.complete_activity(
        user.id,
        "Running",
        effort_value=5,
        effort_unit="km",
    )
    db.session.commit()

    goal = GoalDAO.latest_active(user.id, activity_type.id)
    assert goal is not None
    assert goal.progress_value == pytest.approx(10.0)


def test_daily_completion_increments_goal_once(ctx):
    user = UserService.create_guest_user()
    db.session.commit()

    area, activity_type = _seed_running_goal(user.id)
    daily = DailyActivityService.list_today(user.id)
    running_activity = next(activity for activity in daily if activity.interest_id == area.id)

    DailyActivityService.complete_daily_activity(
        user.id,
        running_activity.id,
        logged_value=5,
        unit="km",
    )
    db.session.commit()

    goal = GoalDAO.latest_active(user.id, activity_type.id)
    assert goal is not None
    assert goal.progress_value == pytest.approx(5.0)


def test_recreate_activity_keeps_active_goal_progress(ctx):
    user = UserService.create_guest_user()
    db.session.commit()

    _, activity_type = _seed_running_goal(user.id)

    ActivityService.complete_activity(
        user.id,
        "Running",
        effort_value=5,
        effort_unit="km",
    )
    db.session.commit()

    goal_before = GoalDAO.latest_active(user.id, activity_type.id)
    assert goal_before is not None
    assert goal_before.progress_value == pytest.approx(5.0)

    ActivityService.create_activity(
        user_id=user.id,
        activity_name="Running",
        interest_name="Running",
        weekly_goal_value=20,
        weekly_goal_unit="km",
    )
    db.session.commit()

    goal_after = GoalDAO.latest_active(user.id, activity_type.id)
    assert goal_after is not None
    assert goal_after.id == goal_before.id

    ActivityService.complete_activity(
        user.id,
        "Running",
        effort_value=5,
        effort_unit="km",
    )
    db.session.commit()

    goal_final = GoalDAO.latest_active(user.id, activity_type.id)
    assert goal_final is not None
    assert goal_final.progress_value == pytest.approx(10.0)


def test_daily_completion_falls_back_to_active_goal(ctx):
    user = UserService.create_guest_user()
    db.session.commit()

    area, activity_type = _seed_running_goal(user.id)
    daily = DailyActivityService.list_today(user.id)
    running_activity = next(activity for activity in daily if activity.interest_id == area.id)

    running_activity.goal_id = None
    db.session.add(running_activity)
    db.session.commit()

    DailyActivityService.complete_daily_activity(
        user.id,
        running_activity.id,
        logged_value=5,
        unit="km",
    )
    db.session.commit()

    goal = GoalDAO.latest_active(user.id, activity_type.id)
    assert goal is not None
    assert goal.progress_value == pytest.approx(5.0)
