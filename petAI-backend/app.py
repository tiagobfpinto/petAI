from pathlib import Path
import sys

from flask import Flask
from flask_cors import CORS
from flask_login import LoginManager
from flask_migrate import Migrate

BASE_DIR = Path(__file__).resolve().parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

from models import bcrypt, db
from config import Config
from models.interests import Interest  # noqa: F401  Ensures Alembic autoload
from models.pet.pet import Pet  # noqa: F401
from models.user.user import User
from routes.auth import auth_bp


def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    CORS(
        app,
        resources={r"/*": {"origins": getattr(Config, "CORS_ORIGINS", ["*"])}},
        supports_credentials=True,
    )

    db.init_app(app)
    bcrypt.init_app(app)
    Migrate(app, db)
    app.register_blueprint(auth_bp)

    login_manager = LoginManager(app)
    login_manager.login_view = "auth.login"

    @login_manager.user_loader
    def load_user(user_id):
        return User.query.get(int(user_id))

    @app.route("/")
    def index():
        return "Hello, Smart World!"

    print("Connected DB:", app.config["SQLALCHEMY_DATABASE_URI"])
    return app


if __name__ == "__main__":
    application = create_app()
    application.run(debug=True)
