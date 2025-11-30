from datetime import datetime, timezone

import pytest

from app import create_app
from app.config import Config, GOAL_COMPLETION_XP
from app.dao.activityDAO import ActivityDAO
from app.dao.interestDAO import InterestDAO
from app.models import db
from app.services.goal_service import GoalService, GoalSnapshot
from app.services.pet_service import PetService
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


def test_suggestions_respect_recent_history(ctx):
    now = datetime(2025, 1, 10, tzinfo=timezone.utc)
    snapshot = GoalSnapshot(
        monthly_goal=100,
        month_progress=25,
        days_left=20,
        recent_amounts=[2.5, 3.0, 4.5],
        today_total=0,
        week_total=0,
        unit="km",
        now=now,
    )
    goals = GoalService._suggestions_from_snapshot(snapshot)
    daily = goals["suggestions"]["daily"]["amount"]
    assert 3 <= daily <= 5.5  # clamped to recent effort range
    assert goals["suggestions"]["weekly"]["amount"] >= daily


def test_goal_rewards_award_bonus_xp(ctx):
    user = UserService.create_guest_user()
    db.session.commit()
    interest = InterestDAO.create(user.id, "Running", "never", None, monthly_goal=30, target_unit="km")
    db.session.commit()
    pet = PetService.get_pet_by_user(user.id)
    now = datetime(2025, 1, 1, 8, tzinfo=timezone.utc)

    entry = ActivityDAO.log(user.id, interest.id, xp_earned=10, amount=3)
    entry.timestamp = now
    db.session.commit()

    rewards = GoalService.apply_goal_rewards(user.id, interest, pet, amount=3, now=now)
    assert rewards["bonus_xp"] >= GOAL_COMPLETION_XP["daily"]
    assert "daily" in rewards["completions"]
    assert pet.xp >= rewards["bonus_xp"]
