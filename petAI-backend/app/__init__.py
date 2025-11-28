from flask import Flask, request 
from flask_cors import CORS
from flask_migrate import Migrate

from .config import Config
from .models import bcrypt, db
from .routes.activity_routes import activity_bp
from .routes.auth_routes import auth_bp
from .routes.hub_routes import hub_bp
from .routes.friend_routes import friends_bp
from .routes.pet_routes import pet_bp
from .routes.user_routes import interests_bp, user_bp


migrate = Migrate()


def create_app(config_class: type[Config] = Config) -> Flask:
    app = Flask(__name__)
    app.config.from_object(config_class)
    print("creating app... ")
    # CORS MUST be configured before blueprints load.
    CORS(
        app,
        resources={r"/*": {"origins": r".*"}},  # regex para ANY origin
        supports_credentials=True,
        allow_headers=["Content-Type", "Authorization"],
        methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    )

    db.init_app(app)
    bcrypt.init_app(app)
    migrate.init_app(app, db)

    app.register_blueprint(auth_bp)
    app.register_blueprint(user_bp)
    app.register_blueprint(interests_bp)
    app.register_blueprint(pet_bp)
    app.register_blueprint(activity_bp)
    app.register_blueprint(friends_bp)
    app.register_blueprint(hub_bp)

    @app.after_request
    def apply_cors(response):
        origin = request.headers.get("Origin")
        if origin:
            response.headers["Access-Control-Allow-Origin"] = origin
            response.headers["Vary"] = "Origin"
        response.headers["Access-Control-Allow-Credentials"] = "true"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
        response.headers["X-CORS-DEBUG"] = "ACTIVE"
        return response

    return app
