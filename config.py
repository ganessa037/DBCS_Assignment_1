import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    SECRET_KEY = os.getenv('SECRET_KEY')
    SERVER_NAME = os.getenv('SERVER_NAME')
    DATABASE_NAME = os.getenv('DATABASE_NAME')
    USERNAME = os.getenv("USERNAME")
    DB_PASSWORD = os.getenv("DB_PASSWORD")

    # flask-limiters
    RATELIMIT_DEFAULT = "200 per day;50 per hour"

    # flask-wtf
    WTF_CSRF_ENABLED = True
    WTF_CSRF_TIME_LIMIT = None

    # attempts
    MAX_LOGIN_ATTEMPTS=5
    LOCKOUT_MINUTES=5


class DevelopmentConfig(Config):
    RATELIMIT_STORAGE_URL='memory://'
    DEBUG=True

class ProductionConfig(Config):
    RATELIMIT_STORAGE_URL='redis://localhost:6379'
    DEBUG=False

config = {
    'development':DevelopmentConfig,
    'production': ProductionConfig,
    'default':DevelopmentConfig
}