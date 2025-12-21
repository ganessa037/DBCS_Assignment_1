from flask_limiter.util import get_remote_address
from flask_limiter import Limiter
from flask_wtf import CSRFProtect

# Initialize extensions
limiter = Limiter(
    key_func=get_remote_address,
    storage_uri="memory://"
)

csrf = CSRFProtect()