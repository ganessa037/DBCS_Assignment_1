from middleware import configure_error_handlers, configure_security_headers
from extensions import limiter, csrf
from dotenv import load_dotenv
from config import config
from flask import Flask
import os

load_dotenv()

def create_app(config_name='default'):
    app = Flask(__name__)
    
    # load config
    app.config.from_object(config[config_name])
    limiter.init_app(app)
    csrf.init_app(app)

    # middleware
    configure_security_headers(app)
    configure_error_handlers(app)

    # register bps
    from routes.auth import auth_bp
    from routes.main import main_bp
    from routes.transactions import transaction_bp
    from routes.admin import admin_bp

    # Apply rate limits to bps
    limiter.limit("5 per minute")(auth_bp.route('/login', methods=['GET', 'POST']))
    limiter.limit("3 per 5 minutes")(auth_bp.route('/register', methods=['GET', 'POST']))
    app.register_blueprint(auth_bp)

    app.register_blueprint(main_bp)

    
    limiter.limit("10 per minute")(transaction_bp.route('/transfer', methods=['POST']))
    limiter.limit("10 per minute")(transaction_bp.route('/deposit', methods=['POST']))
    app.register_blueprint(transaction_bp)
    
    app.register_blueprint(admin_bp)

    return app

if __name__ == '__main__':
    env = os.getenv('FLASK_ENV', 'development')
    if env not in ['development', 'production'] : env = 'development'
    app = create_app(env)
    app.run(debug=(env=='development'), port=5000)