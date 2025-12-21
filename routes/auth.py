from flask import Blueprint, render_template, request, redirect, url_for, session, flash
from utils.validation import validate_email, validate_name, validate_password
from utils.security import hash_password, generate_salt, get_client_ip
from database import get_db_connection, get_user_role_name
from datetime import datetime, timedelta
from extensions import limiter

auth_bp = Blueprint('auth', __name__)

# Brute force protection - track failed login attempts
failed_attempts = {}  # {email: {'count': 0, 'lockout_until': None}}
MAX_ATTEMPTS = 5
LOCKOUT_MINUTES = 5

@auth_bp.route('/')
def home():
    return redirect(url_for('auth.login'))

@auth_bp.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        email = request.form['email']
        password_input = request.form['password']

        # Check if account is locked
        if email in failed_attempts:
            lockout_until = failed_attempts[email].get('lockout_until')
            if lockout_until and datetime.now() < lockout_until:
                remaining = (lockout_until - datetime.now()).seconds // 60 + 1
                flash(f"Account locked. Try again in {remaining} minute(s).", "error")
                return render_template('login.html')
            elif lockout_until and datetime.now() >= lockout_until:
                # Reset after lockout expires
                failed_attempts[email] = {'count': 0, 'lockout_until': None}

        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT UserID, User_Name, User_PasswordHash, User_Salt, RoleID FROM [User] WHERE User_Email = ?", (email,))
        user = cursor.fetchone()

        if user:
            stored_hash = user.User_PasswordHash
            stored_salt = user.User_Salt
            input_hash = hash_password(password_input, stored_salt) #Re-create the hash using the Input Password + Stored Salt
            
            if input_hash == stored_hash:
                if email in failed_attempts:
                    del failed_attempts[email]

                session['user_id'] = user.UserID
                session['user_name'] = user.User_Name
                session['role_id'] = user.RoleID

                # Update last_login timestamp
                try:
                    cursor.execute("UPDATE [User] SET Last_Login = GETDATE() WHERE UserID = ?", (user.UserID,))
                except:
                    # If Last_Login column doesn't exist or has different name, try alternatives
                    try:
                        cursor.execute("UPDATE [User] SET last_login = GETDATE() WHERE UserID = ?", (user.UserID,))
                    except:
                        pass  # Column might not exist, skip silently

                role_name = get_user_role_name(cursor, user.UserID)
                ip_address = get_client_ip()
                cursor.execute("""
                    INSERT INTO Audit_Log (UserID, User_Name, Role_Name, Action_Type, Status, Message, IP_Address)
                    VALUES (?, ?, ?, 'LOGIN', 'Success', 'User logged in successfully', ?)
                """, (user.UserID, user.User_Name, role_name, ip_address))
                conn.commit()
            
                return redirect(url_for('main.dashboard'))
            else:
                if email not in failed_attempts:
                    failed_attempts[email] = {'count': 0, 'lockout_until': None}
                failed_attempts[email]['count'] += 1
                attempts_left = MAX_ATTEMPTS - failed_attempts[email]['count']
                if attempts_left <= 0:
                    failed_attempts[email]['lockout_until'] = datetime.now() + timedelta(minutes=LOCKOUT_MINUTES)
                    flash(f"Too many failed attempts. Account locked for {LOCKOUT_MINUTES} minutes.", "error")
                else:
                    flash(f"Invalid Password! {attempts_left} attempt(s) remaining.", "error")
        else:
            flash("User not found!", "error")
        conn.close()
    return render_template('login.html')

@auth_bp.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        name = request.form['name'].strip()
        email = request.form['email'].strip()
        password = request.form['password']
        errors = [] # list of errors

        if not validate_email(email): errors.append("Please enter a valid email address.")
        
        is_valid, error = validate_name(name)
        if not is_valid: errors.append(error)

        is_valid, password_errors = validate_password(password)
        if not is_valid: errors.extend(password_errors)

        if errors:
            for error in errors:
                flash(error, "error")
            return render_template('register.html')
        
        # SECURITY: Create a unique Salt and Hash
        new_salt = generate_salt()
        new_hash = hash_password(password, new_salt)
        
        conn = get_db_connection()
        cursor = conn.cursor()

        try:
            # Check if email already exists
            cursor.execute("SELECT UserID FROM [User] WHERE User_Email = ?", (email,))
            if cursor.fetchone():
                flash("This email is already registered. Please use a different email or login.", "error")
                return render_template('register.html')
            
            # Default Role = 2 (Customer)
            cursor.execute("""
                INSERT INTO [User] (User_Name, User_Email, User_PasswordHash, User_Salt, RoleID)
                VALUES (?, ?, ?, ?, 2)
            """, (name, email, new_hash, new_salt))

            # Create account
            cursor.execute("SELECT @@IDENTITY") # Get the new UserID
            new_user_id = cursor.fetchone()[0]

            cursor.execute("""
                INSERT INTO Account (UserID, Acc_Number, Acc_Balance)
                VALUES (?, '100-' + CAST(? AS VARCHAR), 0.00)
            """, (new_user_id, new_user_id)) # Simple logic for Acc Number

            conn.commit()
            flash("Registration Successful! Please Login.", "success")
            return redirect(url_for('login'))
        except Exception as e:
            flash("Registration failed. Please try again later.", "error")
        finally:
            conn.close()

    return render_template('register.html')

@auth_bp.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('auth.login'))