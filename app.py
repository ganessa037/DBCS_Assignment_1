from flask import Flask, render_template, request, redirect, url_for, session, flash
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_wtf import CSRFProtect
import pyodbc
import hashlib
import os
from datetime import datetime, timedelta

app = Flask(__name__)
app.secret_key = 'super_secret_key_ironvault'  # Required for session management

# add limiter
limiter = Limiter(
    key_func= get_remote_address,
    default_limits=["200 per day", "50 per hour"]
)
limiter.init_app(app)
csrf = CSRFProtect(app)

# security: stops back button after logout
@app.after_request
def add_security_headers(response):
    # cache control headers
    response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, max-age=0'
    response.headers['Pragma'] = 'no-cache'
    response.headers['Expires'] = '0'

    # X-Frame-Options header to prevent clickjacking
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-XSS-Protection'] = '1; mode=block'

    # remove server printing
    response.headers.pop('Server', None)

    # enable HSTS if HTTPS is used
    if request.is_secure:
        response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'

    return response

@app.errorhandler(400)
def handle_csrf_error(e):
    return render_template('csrf_error.html', message="CSRF token missing or invalid."), 40

# Brute force protection - track failed login attempts
failed_attempts = {}  # {email: {'count': 0, 'lockout_until': None}}
MAX_ATTEMPTS = 5
LOCKOUT_MINUTES = 5

# --- DATABASE CONFIGURATION ---
# UPDATE THIS with your actual server name!
SERVER_NAME = 'localhost'  # SQL Server Developer Edition (default instance)
DATABASE_NAME = 'IronVaultDB'

def get_db_connection():
    conn_str = (
        f'DRIVER={{ODBC Driver 17 for SQL Server}};' # this is the driver for the SQL Server, this is required to connect to the SQL Server
        f'SERVER={SERVER_NAME};'
        f'DATABASE={DATABASE_NAME};'
        f'Trusted_Connection=yes;'
    )
    return pyodbc.connect(conn_str)

# --- SECURITY FUNCTIONS (The "Salt" Magic) ---

def hash_password(password, salt):
    """
    Combines Password + Salt and then Hashes it.
    This creates the 'Unique Smoothie'.
    """
    salted_password = password + salt
    # We use SHA256 (Secure Hash Algorithm)
    return hashlib.sha256(salted_password.encode()).hexdigest()

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

def get_user_role_name(cursor, user_id):
    """Get the role name for a user"""
    try:
        cursor.execute("""
            SELECT r.Role_Name 
            FROM [User] u
            JOIN [Role] r ON u.RoleID = r.RoleID
            WHERE u.UserID = ?
        """, (user_id,))
        result = cursor.fetchone()
        return result[0] if result else None
    except:
        return None

# --- ROUTES ---

@app.route('/')
def home():
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
@limiter.limit("5 per minute")
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
        
        # 1. Fetch the user's Salt and Hash from DB
        cursor.execute("SELECT UserID, User_Name, User_PasswordHash, User_Salt, RoleID FROM [User] WHERE User_Email = ?", (email,))
        user = cursor.fetchone()
        
        if user:
            stored_hash = user.User_PasswordHash
            stored_salt = user.User_Salt
            
            # 2. Re-create the hash using the Input Password + Stored Salt
            input_hash = hash_password(password_input, stored_salt)
            
            # 3. Compare: Does the new smoothie match the stored smoothie?
            if input_hash == stored_hash:
                # Reset failed attempts on successful login
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
                
                # SECURITY AUDIT: Log the successful login
                role_name = get_user_role_name(cursor, user.UserID)
                ip_address = get_client_ip()
                cursor.execute("""
                    INSERT INTO Audit_Log (UserID, User_Name, Role_Name, Action_Type, Status, Message, IP_Address)
                    VALUES (?, ?, ?, 'LOGIN', 'Success', 'User logged in successfully', ?)
                """, (user.UserID, user.User_Name, role_name, ip_address))
                conn.commit()
                
                return redirect(url_for('dashboard'))
            else:
                # Track failed attempt
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

@app.route('/dashboard')
def dashboard():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Variables
    my_accounts = []
    my_transactions = []
    all_customer_accounts = [] 
    security_logs = []       
    admin_user_list = []      # NEW: For Admin User Management
    
    role_id = session['role_id']
    
    # --- 1. CUSTOMER DATA (Everyone gets this) ---
    cursor.execute("SELECT * FROM Account WHERE UserID = ?", (session['user_id'],))
    my_accounts = cursor.fetchall()
    
    user_id = session['user_id']
    cursor.execute("""
        SELECT 
            t.TransactionID,
            t.Transaction_Date,
            t.Transaction_Type,
            t.Amount,
            t.Description,
            t.SenderAccountID,
            t.ReceiverAccountID,
            sender.Acc_Number as SenderAccount,
            receiver.Acc_Number as ReceiverAccount,
            CASE 
                WHEN t.SenderAccountID IN (SELECT AccountID FROM Account WHERE UserID = ?) THEN 'Debit'
                ELSE 'Credit'
            END as Transaction_Direction
        FROM [Transaction] t
        LEFT JOIN Account sender ON t.SenderAccountID = sender.AccountID
        LEFT JOIN Account receiver ON t.ReceiverAccountID = receiver.AccountID
        WHERE t.SenderAccountID IN (SELECT AccountID FROM Account WHERE UserID = ?) 
           OR t.ReceiverAccountID IN (SELECT AccountID FROM Account WHERE UserID = ?)
        ORDER BY t.Transaction_Date DESC
    """, (user_id, user_id, user_id))
    rows = cursor.fetchall()
    # Convert pyodbc Row objects to dictionaries for easier template access
    columns = [column[0] for column in cursor.description]
    my_transactions = []
    for row in rows:
        row_dict = {}
        for i, col_name in enumerate(columns):
            row_dict[col_name] = row[i]
        my_transactions.append(row_dict)

    # --- 2. MANAGER DATA (Role 3) ---
    if role_id == 3: 
        cursor.execute("""
            SELECT u.UserID, u.User_Name, u.User_Email, a.Acc_Number, a.Acc_Balance 
            FROM Account a
            JOIN [User] u ON a.UserID = u.UserID
            JOIN [Role] r ON u.RoleID = r.RoleID
            WHERE r.Role_Name = 'Customer'
        """)
        rows = cursor.fetchall()
        # Convert pyodbc Row objects to dictionaries for easier template access
        columns = [column[0] for column in cursor.description]
        all_customer_accounts = []
        for row in rows:
            # Convert tuple/Row to dictionary
            row_dict = {}
            for i, col_name in enumerate(columns):
                row_dict[col_name] = row[i]
            all_customer_accounts.append(row_dict)

    # --- 3. ADMIN DATA (Role 1) ---
    if role_id == 1:
        # A. Get Security Logs
        cursor.execute("SELECT TOP 50 * FROM Audit_Log ORDER BY Action_Date DESC")
        security_logs = cursor.fetchall()
        
        # B. Get All Users for Management (NEW)
        try:
            cursor.execute("""
                SELECT u.UserID, u.User_Name, u.User_Email, r.Role_Name, u.RoleID, ISNULL(u.Status, 'Active') as Status
                FROM [User] u
                JOIN [Role] r ON u.RoleID = r.RoleID
            """)
        except:
            # Fallback if Status column doesn't exist
            cursor.execute("""
                SELECT u.UserID, u.User_Name, u.User_Email, r.Role_Name, u.RoleID, 'Active' as Status
                FROM [User] u
                JOIN [Role] r ON u.RoleID = r.RoleID
            """)
        rows = cursor.fetchall()
        # Convert pyodbc Row objects to dictionaries for easier template access
        columns = [column[0] for column in cursor.description]
        admin_user_list = []
        for row in rows:
            # Convert tuple/Row to dictionary
            row_dict = {}
            for i, col_name in enumerate(columns):
                row_dict[col_name] = row[i]
            admin_user_list.append(row_dict)

    conn.close()
    
    return render_template('dashboard.html', 
                           user_name=session['user_name'], 
                           role_id=role_id,
                           accounts=my_accounts, 
                           transactions=my_transactions,
                           all_customers=all_customer_accounts,
                           audit_logs=security_logs,
                           admin_users=admin_user_list)  # Pass the list to HTML


@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

# --- REGISTRATION (To create users with Salts) ---
@app.route('/register', methods=['GET', 'POST'])
@limiter.limit("3 per 5 minutes")
def register():
    if request.method == 'POST':
        name = request.form['name'].strip()
        email = request.form['email'].strip()
        password = request.form['password']
        errors = [] # list of errors
        
        # Email validation
        import re
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(email_pattern, email):
            errors.append("Please enter a valid email address.")
        
        # Name validation
        if len(name) < 2:
            errors.append("Name must be at least 2 characters.")
        
        # Password validation
        if len(password) < 8:
            errors.append("Password must be at least 8 characters long.")
        if not any(c.isalpha() for c in password):
            errors.append("Password must contain at least one letter.")
        if not any(c.isdigit() for c in password):
            errors.append("Password must contain at least one number.")
        if not any(c in "!@#$%^&*()_+-=[]{}|;:',.<>?/" for c in password):
            errors.append("Password must contain at least one special character.")

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
            
            # Create a dummy account for them automatically
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

@app.route('/delete_user/<int:user_id>', methods=['POST'])
def delete_user(user_id):
    if 'role_id' not in session or session['role_id'] != 3: # Only Manager can delete
        flash("Unauthorized Action!", "error")
        return redirect(url_for('dashboard'))
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # Check if user exists first
        cursor.execute("SELECT UserID, User_Name FROM [User] WHERE UserID = ?", (user_id,))
        user_check = cursor.fetchone()
        if not user_check:
            flash(f"User ID {user_id} not found!", "error")
            conn.close()
            return redirect(url_for('dashboard'))
        
        # 1. Delete audit logs for this user (if foreign key exists)
        try:
            cursor.execute("DELETE FROM Audit_Log WHERE UserID = ?", (user_id,))
            audit_deleted = cursor.rowcount
        except:
            pass  # Ignore if table doesn't exist or no FK constraint
        
        # 2. Delete their transactions first (Foreign Key Constraint)
        cursor.execute("DELETE FROM [Transaction] WHERE SenderAccountID IN (SELECT AccountID FROM Account WHERE UserID = ?) OR ReceiverAccountID IN (SELECT AccountID FROM Account WHERE UserID = ?)", (user_id, user_id))
        trans_deleted = cursor.rowcount
        
        # 3. Delete their accounts
        cursor.execute("DELETE FROM Account WHERE UserID = ?", (user_id,))
        accounts_deleted = cursor.rowcount
        
        # 4. Delete the user
        cursor.execute("DELETE FROM [User] WHERE UserID = ?", (user_id,))
        user_deleted = cursor.rowcount
        
        if user_deleted == 0:
            flash(f"Failed to delete user ID {user_id}. User may not exist.", "error")
            conn.rollback()
            conn.close()
            return redirect(url_for('dashboard'))
        
        conn.commit()
        
        # 5. Log this action (Security Requirement) - Use session user info
        try:
            role_name = get_user_role_name(cursor, session['user_id'])
            ip_address = get_client_ip()
            cursor.execute("""
                INSERT INTO Audit_Log (UserID, User_Name, Role_Name, Action_Type, Status, Message, IP_Address)
                VALUES (?, ?, ?, 'DELETE_USER', 'Success', ?, ?)
            """, (session['user_id'], session['user_name'], role_name, f'Deleted User ID {user_id}', ip_address))
            conn.commit()
        except Exception as log_error:
            print(f"Warning: Could not log audit entry: {log_error}")
        
        flash(f"User deleted successfully!", "success")
    except Exception as e:
        conn.rollback()
        error_msg = str(e)
        flash("Failed to delete user. Please try again.", "error")
        print(f"Delete error: {error_msg}")  # Debug output
    finally:
        conn.close()
        
    return redirect(url_for('dashboard'))

@app.route('/transfer', methods=['POST'])
@limiter.limit("10 per minute")
def transfer():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    # Only customers can transfer
    if session.get('role_id') != 2:
        flash("Unauthorized: Only customers can transfer money!", "error")
        return redirect(url_for('dashboard'))
    
    sender_id = session['user_id']
    receiver_acc_num = request.form.get('receiver_acc', '').strip()
    amount_str = request.form.get('amount', '').strip()
    
    # Validation
    if not receiver_acc_num:
        flash("Receiver Account Number is required!", "error")
        return redirect(url_for('dashboard'))
    
    try:
        amount = float(amount_str)
        if amount <= 0:
            flash("Amount must be greater than 0!", "error")
            return redirect(url_for('dashboard'))
    except ValueError:
        flash("Invalid amount format!", "error")
        return redirect(url_for('dashboard'))
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # 1. Get Sender Account (use first account if multiple exist)
        cursor.execute("SELECT AccountID, Acc_Balance FROM Account WHERE UserID = ?", (sender_id,))
        sender_acc = cursor.fetchone()
        
        if not sender_acc:
            flash("Sender account not found!", "error")
            conn.close()
            return redirect(url_for('dashboard'))
        
        # Access pyodbc Row by index
        sender_account_id = sender_acc[0]
        sender_balance = float(sender_acc[1])
        
        if sender_balance < amount:
            flash(f"Insufficient Funds! Your balance is RM {sender_balance:.2f}", "error")
            conn.close()
            return redirect(url_for('dashboard'))
            
        # 2. Find Receiver Account
        cursor.execute("SELECT AccountID, Acc_Balance, UserID FROM Account WHERE Acc_Number = ?", (receiver_acc_num,))
        receiver_acc = cursor.fetchone()
        
        if not receiver_acc:
            flash(f"Receiver Account '{receiver_acc_num}' Not Found!", "error")
            conn.close()
            return redirect(url_for('dashboard'))
        
        receiver_account_id = receiver_acc[0]
        receiver_user_id = receiver_acc[2]
        
        # Prevent self-transfer
        if sender_account_id == receiver_account_id:
            flash("Cannot transfer to the same account!", "error")
            conn.close()
            return redirect(url_for('dashboard'))

        # --- DATABASE TRANSACTION (ACID) ---
        # 3. Deduct from Sender
        cursor.execute("UPDATE Account SET Acc_Balance = Acc_Balance - ? WHERE AccountID = ?", (amount, sender_account_id))
        
        # 4. Add to Receiver
        cursor.execute("UPDATE Account SET Acc_Balance = Acc_Balance + ? WHERE AccountID = ?", (amount, receiver_account_id))
        
        # 5. Record the Transaction
        cursor.execute("""
            INSERT INTO [Transaction] (SenderAccountID, ReceiverAccountID, Amount, Transaction_Type, Description)
            VALUES (?, ?, ?, 'TRANSFER', 'Online Transfer')
        """, (sender_account_id, receiver_account_id, amount))
        
        # 6. Audit Log
        role_name = get_user_role_name(cursor, sender_id)
        ip_address = get_client_ip()
        cursor.execute("""
            INSERT INTO Audit_Log (UserID, User_Name, Role_Name, Action_Type, Status, Message, IP_Address)
            VALUES (?, ?, ?, 'TRANSFER', 'Success', ?, ?)
        """, (sender_id, session['user_name'], role_name, f'Transferred RM {amount:.2f} to account {receiver_acc_num}', ip_address))
        
        conn.commit()
        flash(f"Successfully transferred RM {amount:.2f} to account {receiver_acc_num}!", "success")
        
    except Exception as e:
        conn.rollback()
        error_msg = str(e)
        flash("Transfer failed. Please try again.", "error")
        print(f"Transfer error: {error_msg}")  # Debug output
        
        # Log failed transfer attempt
        try:
            role_name = get_user_role_name(cursor, sender_id)
            ip_address = get_client_ip()
            cursor.execute("""
                INSERT INTO Audit_Log (UserID, User_Name, Role_Name, Action_Type, Status, Message, IP_Address)
                VALUES (?, ?, ?, 'TRANSFER', 'Failed', ?, ?)
            """, (sender_id, session.get('user_name', 'Unknown'), role_name, f'Transfer failed: {error_msg}', ip_address))
            conn.commit()
        except:
            pass
    finally:
        conn.close()
        
    return redirect(url_for('dashboard'))

@app.route('/deposit', methods=['POST'])
@limiter.limit("10 per minute")
def deposit():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    # Only customers can deposit
    if session.get('role_id') != 2:
        flash("Unauthorized: Only customers can make deposits!", "error")
        return redirect(url_for('dashboard'))
    
    amount_str = request.form.get('amount', '').strip()
    
    # Validation
    try:
        amount = float(amount_str)
        if amount <= 0:
            flash("Amount must be greater than 0!", "error")
            return redirect(url_for('dashboard'))
    except ValueError:
        flash("Invalid amount format!", "error")
        return redirect(url_for('dashboard'))
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # Get user's account ID (use first account if multiple exist)
        cursor.execute("SELECT AccountID FROM Account WHERE UserID = ?", (session['user_id'],))
        account = cursor.fetchone()
        
        if not account:
            flash("Account not found!", "error")
            conn.close()
            return redirect(url_for('dashboard'))
        
        # Access pyodbc Row by index
        account_id = account[0]
        
        # Add money
        cursor.execute("UPDATE Account SET Acc_Balance = Acc_Balance + ? WHERE AccountID = ?", (amount, account_id))
        
        # Record Transaction
        cursor.execute("""
            INSERT INTO [Transaction] (ReceiverAccountID, Amount, Transaction_Type, Description)
            VALUES (?, ?, 'DEPOSIT', 'ATM Cash Deposit')
        """, (account_id, amount))
        
        # Audit Log
        role_name = get_user_role_name(cursor, session['user_id'])
        ip_address = get_client_ip()
        cursor.execute("""
            INSERT INTO Audit_Log (UserID, User_Name, Role_Name, Action_Type, Status, Message, IP_Address)
            VALUES (?, ?, ?, 'DEPOSIT', 'Success', ?, ?)
        """, (session['user_id'], session['user_name'], role_name, f'Deposited RM {amount:.2f}', ip_address))
        
        conn.commit()
        flash(f"Successfully deposited RM {amount:.2f}!", "success")
        
    except Exception as e:
        conn.rollback()
        error_msg = str(e)
        flash("Deposit failed. Please try again.", "error")
        print(f"Deposit error: {error_msg}")  # Debug output
        
        # Log failed deposit attempt
        try:
            role_name = get_user_role_name(cursor, session['user_id'])
            ip_address = get_client_ip()
            cursor.execute("""
                INSERT INTO Audit_Log (UserID, User_Name, Role_Name, Action_Type, Status, Message, IP_Address)
                VALUES (?, ?, ?, 'DEPOSIT', 'Failed', ?, ?)
            """, (session['user_id'], session.get('user_name', 'Unknown'), role_name, f'Deposit failed: {error_msg}', ip_address))
            conn.commit()
        except:
            pass
    finally:
        conn.close()
        
    return redirect(url_for('dashboard'))

@app.route('/update_role', methods=['POST'])
def update_role():
    if 'role_id' not in session or session['role_id'] != 1:  # Strict Admin Check
        flash("Unauthorized!", "error")
        return redirect(url_for('dashboard'))
    
    target_user_id = request.form.get('user_id')
    new_role_id = request.form.get('new_role')
    new_status = request.form.get('status', 'Active')
    
    if not target_user_id or not new_role_id:
        flash("Missing required fields!", "error")
        return redirect(url_for('dashboard'))
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # Check if user exists
        cursor.execute("SELECT UserID, RoleID FROM [User] WHERE UserID = ?", (target_user_id,))
        user_check = cursor.fetchone()
        
        if not user_check:
            flash(f"User ID {target_user_id} not found!", "error")
            conn.close()
            return redirect(url_for('dashboard'))
        
        old_role_id = user_check[1]
        changes = []
        
        # 1. Update the User's Role if changed
        if int(old_role_id) != int(new_role_id):
            cursor.execute("UPDATE [User] SET RoleID = ? WHERE UserID = ?", (new_role_id, target_user_id))
            role_names = {1: 'Admin', 2: 'Customer', 3: 'Manager'}
            old_role_name = role_names.get(int(old_role_id), 'Unknown')
            new_role_name = role_names.get(int(new_role_id), 'Unknown')
            changes.append(f"Role: {old_role_name} → {new_role_name}")
        
        # 2. Update Status if Status column exists
        try:
            cursor.execute("UPDATE [User] SET Status = ? WHERE UserID = ?", (new_status, target_user_id))
            changes.append(f"Status: {new_status}")
        except:
            # Status column doesn't exist, skip
            pass
        
        if not changes:
            flash("No changes made!", "info")
            conn.close()
            return redirect(url_for('dashboard'))
        
        # 3. Log it (Security Requirement)
        role_names = {1: 'Admin', 2: 'Customer', 3: 'Manager'}
        new_role_name = role_names.get(int(new_role_id), 'Unknown')
        changes_msg = "; ".join(changes)
        role_name = get_user_role_name(cursor, session['user_id'])
        ip_address = get_client_ip()
        
        cursor.execute("""
            INSERT INTO Audit_Log (UserID, User_Name, Role_Name, Action_Type, Status, Message, IP_Address)
            VALUES (?, ?, ?, 'USER_UPDATE', 'Success', ?, ?)
        """, (session['user_id'], session['user_name'], role_name, f"Updated User {target_user_id}: {changes_msg}", ip_address))
        
        conn.commit()
        flash(f"User updated successfully!", "success")
        
    except Exception as e:
        conn.rollback()
        error_msg = str(e)
        flash("Failed to update user. Please try again.", "error")
        print(f"Update user error: {error_msg}")  # Debug output
    finally:
        conn.close()
        
    return redirect(url_for('dashboard'))

if __name__ == '__main__':
    app.run(debug=True, port=5000)