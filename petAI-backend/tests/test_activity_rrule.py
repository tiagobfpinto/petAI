import pytest
from datetime import datetime, timezone, timedelta

from app import create_app
from app.config import Config
from app.models import db
from app.services.user_service import UserService
from app.services.interest_service import InterestService
from app.services.activity_service import ActivityService
from app.dao.daily_activityDAO import DailyActivityDAO


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


def test_rrule_creates_daily_tasks(ctx):
    user = UserService.create_guest_user()
    db.session.commit()

    InterestService.save_user_interests(user.id, [{"name": "Study", "level": "sometimes"}])
    db.session.commit()

    ActivityService.create_activity(
        user_id=user.id,
        activity_name="Study Calculus",
        interest_name="Study",
        rrule="FREQ=DAILY;COUNT=2",
    )
    db.session.commit()

    today = datetime.now(timezone.utc).date()
    tomorrow = today + timedelta(days=1)

    today_entries = DailyActivityDAO.list_for_user_on_date(user.id, today)
    tomorrow_entries = DailyActivityDAO.list_for_user_on_date(user.id, tomorrow)

    assert len(today_entries) == 1
    assert len(tomorrow_entries) == 1
    assert today_entries[0].title == "Study Calculus"
    assert tomorrow_entries[0].title == "Study Calculus"
