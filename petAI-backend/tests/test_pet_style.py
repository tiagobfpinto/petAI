import pytest

from app import create_app
from app.config import Config
from app.models import db
from app.models.petStyle import PetStyle
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


def test_pet_creation_bootstraps_pet_style(app):
    with app.app_context():
        user = UserService.create_guest_user()
        db.session.commit()

        pet = PetService.get_pet_by_user(user.id)
        assert pet is not None

        style = PetStyle.query.filter_by(pet_id=pet.id).first()
        assert style is not None


def test_create_pet_is_idempotent_for_pet_style(app):
    with app.app_context():
        user = UserService.create_guest_user()
        db.session.commit()

        pet = PetService.get_pet_by_user(user.id)
        assert pet is not None

        PetService.create_pet(user.id)
        db.session.commit()

        assert PetStyle.query.filter_by(pet_id=pet.id).count() == 1

