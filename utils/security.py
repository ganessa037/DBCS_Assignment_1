from flask import request
import hashlib
import os

def hash_password(password, salt):
    """
    Combines Password + Salt and then Hashes it.
    This creates the 'Unique Smoothie'.
    """
    salted_password = password + salt
    return hashlib.sha256(salted_password.encode()).hexdigest() # use standard SHA256

def generate_salt():
    """Generates a random 16-character string (The 'Spice')"""
    return os.urandom(16).hex()

def get_client_ip():
    """Get the client's IP address from the request"""
    if request.headers.get('X-Forwarded-For'):
        ip = request.headers.get('X-Forwarded-For').split(',')[0].strip()
    elif request.headers.get('X-Real-IP'):
        ip = request.headers.get('X-Real-IP')
    else:
        ip = request.remote_addr
    return ip