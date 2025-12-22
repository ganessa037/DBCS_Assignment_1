from flask import session, flash, redirect, url_for
from flask_limiter.util import get_remote_address
from flask_limiter import Limiter
from flask_wtf import CSRFProtect
from functools import wraps

# Initialize extensions
limiter = Limiter(
    key_func=get_remote_address,
    storage_uri="memory://"
)

csrf = CSRFProtect()

def role_required(*allowed_roles):
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if 'user_id' not in session: return redirect(url_for('auth.login'))
            if 'role_id' not in session or session['role_id'] not in allowed_roles:
                flash("Unauthorized Action!", "error")
                return redirect(url_for('main.dashboard'))
            return f(*args, **kwargs)
        return decorated_function
    return decorator