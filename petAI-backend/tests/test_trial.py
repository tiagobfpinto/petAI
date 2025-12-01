from datetime import datetime, timedelta, timezone

import pytest

from app import create_app
from app.config import Config
from app.models import db
from app.auth.token_auth import active_user_required, token_required
from app.dao.userDAO import UserDAO
from app.services.auth_token_service import AuthTokenService
from app.services.user_service import UserService


class TestConfig(Config):
    SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
    TESTING = True
    AUTH_TOKEN_EXPIRES_SECONDS = 60 * 60  # 1h for tests


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


def test_trial_days_and_deactivation(ctx):
    base_time = datetime.now(timezone.utc)
    user = UserService.create_guest_user()
    db.session.commit()

    # Issue a token so we can verify revocation on deactivate.
    token_value = AuthTokenService.issue_token(user.id)
    db.session.commit()
    assert token_value

    user.created_at = base_time
    db.session.commit()
    assert UserService._trial_days_left(user) == 3

    user.created_at = base_time - timedelta(days=1)
    db.session.commit()
    assert UserService._trial_days_left(user) == 2

    user.created_at = base_time - timedelta(days=2)
    db.session.commit()
    assert UserService._trial_days_left(user) == 1

    user.created_at = base_time - timedelta(days=3)
    db.session.commit()
    assert UserService._trial_days_left(user) == 0

    assert UserService.deactivate_user(user.id) is True
    db.session.refresh(user)
    assert user.is_active is False
    assert len(user.tokens) == 0

    assert UserService.reactivate_user(user.id) is True
    db.session.refresh(user)
    assert user.is_active is True


def test_token_blocked_when_trial_expired(app):
    client = app.test_client()
    with app.app_context():
        user = UserService.create_guest_user()
        db.session.commit()
        user_id = user.id
        token_value = AuthTokenService.issue_token(user_id)
        db.session.commit()

        user.created_at = datetime.now(timezone.utc) - timedelta(days=4)
        db.session.commit()

    @app.route("/protected")
    @token_required  # type: ignore[misc]
    @active_user_required  # type: ignore[misc]
    def protected():  # pragma: no cover - minimal route for testing
        return "ok"

    headers = {"Authorization": f"Bearer {token_value}"}
    resp = client.get("/protected", headers=headers)
    assert resp.status_code == 403

    with app.app_context():
        user_obj = UserDAO.get_by_id(user_id)
        assert user_obj is not None
        assert user_obj.is_active is False


def test_streak_multiplier_scaling(ctx):
    assert UserService.streak_multiplier(0) == 1.0
    assert UserService.streak_multiplier(1) == 1.0
    assert UserService.streak_multiplier(5) == 1.44  # (5-1)/9 = 0.44
    assert UserService.streak_multiplier(10) == 2.0
    assert UserService.streak_multiplier(25) == 2.0  # capped
