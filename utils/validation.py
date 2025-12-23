import re

def validate_email(email):
    email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(email_pattern, email) is not None

def validate_password(password):
    errors = []

    if len(password) < 8:
        errors.append("Password must be at least 8 characters long.")
    if not any(c.isalpha() for c in password):
        errors.append("Password must contain at least one letter.")
    if not any(c.isdigit() for c in password):
        errors.append("Password must contain at least one number.")
    if not any(c in "!@#$%^&*()_+-=[]{}|;:',.<>?/" for c in password):
        errors.append("Password must contain at least one special character.")

    return len(errors) == 0, errors

def validate_name(name):
    if len(name) < 2:
        return False, "Name must be at least 2 characters."
    return True, None