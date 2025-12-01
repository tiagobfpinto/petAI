import pytest

from app import create_app
from app.config import Config
from app.models import db
from app.services.activity_service import ActivityService
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


def test_activity_history_survives_interest_changes(ctx):
    user = UserService.create_guest_user()
    db.session.commit()

    initial_entries = [
        {
            "name": "Running",
            "level": "sometimes",
            "goal": "Jog 3km",
            "plan": {"weekly_goal_value": 4, "weekly_goal_unit": "km", "days": ["mon", "wed"]},
        },
        {"name": "Study", "level": "always"},
    ]
    interests = UserService.save_user_interests(user.id, initial_entries)
    db.session.commit()
    running = next(item for item in interests if item["name"] == "Running")
    running_id = running["id"]

    ActivityService.complete_activity(user.id, "Running")
    db.session.commit()
    today_logs = ActivityService.today_activities(user.id)
    assert any(log.interest_id == running_id for log in today_logs)

    updated_entries = initial_entries + [{"name": "Yoga", "level": "never"}]
    updated_interests = UserService.save_user_interests(user.id, updated_entries)
    db.session.commit()

    running_after = next(item for item in updated_interests if item["name"] == "Running")
    assert running_after["id"] == running_id

    logs_after = ActivityService.today_activities(user.id)
    assert any(log.interest_id == running_id for log in logs_after)


def test_running_plan_saved_with_days(ctx):
    user = UserService.create_guest_user()
    db.session.commit()

    entries = [
        {
            "name": "Running",
            "level": "never",
            "plan": {"weekly_goal_value": 4, "weekly_goal_unit": "km", "days": ["monday", "wed"]},
        }
    ]

    interests = UserService.save_user_interests(user.id, entries)
    db.session.commit()

    running = interests[0]
    assert running["plan"] is not None
    assert running["plan"]["weekly_goal_value"] == 4
    assert running["plan"]["weekly_goal_unit"] == "km"
    assert running["plan"]["days"] == ["mon", "wed"]
