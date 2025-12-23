from flask import Blueprint, render_template, request, redirect, url_for, session, flash
from database import get_db_connection

main_bp = Blueprint('main', __name__)

@main_bp.route('/dashboard')
def dashboard():
    if 'user_id' not in session : return redirect(url_for('auth.login'))
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    role_id = session['role_id']
    user_id = session['user_id']
    
    # CUSTOMER DATA (Everyone gets this)
    cursor.execute("EXEC dbo.sp_GetAccountsByUser @UserID = ?", (user_id,))
    my_accounts = [dict(zip([column[0] for column in cursor.description], row)) for row in cursor.fetchall()]
    if my_accounts:
        user_name = my_accounts[0]['User_Name']
    
    user_id = session['user_id']
    cursor.execute("EXEC dbo.sp_GetTransactionsByUser @UserID = ?", (user_id,))
    rows = cursor.fetchall()
    columns = [column[0] for column in cursor.description]
    my_transactions = [dict(zip(columns, row)) for row in rows]

    # MANAGER DATA (Role 3)
    all_customer_accounts = []
    if role_id == 3: 
        cursor.execute("EXEC dbo.sp_GetAllCustomerAccounts")
        rows = cursor.fetchall()
        columns = [column[0] for column in cursor.description]
        all_customer_accounts = [dict(zip(columns, row)) for row in rows]

    # ADMIN DATA (Role 1)
    security_logs = []
    admin_user_list = []
    if role_id == 1:
        # Get recent audit logs
        cursor.execute("EXEC dbo.sp_GetAuditLogs @Top = ?", (50,))
        rows = cursor.fetchall()
        columns = [column[0] for column in cursor.description]
        security_logs = [dict(zip(columns, row)) for row in rows]

        # Get all users for management
        cursor.execute("EXEC dbo.sp_GetAllUsers")
        rows = cursor.fetchall()
        columns = [column[0] for column in cursor.description]
        admin_user_list = [dict(zip(columns, row)) for row in rows]

    conn.close()
    
    return render_template('dashboard.html', 
                           user_name=user_name, 
                           role_id=role_id,
                           accounts=my_accounts, 
                           transactions=my_transactions,
                           all_customers=all_customer_accounts,
                           audit_logs=security_logs,
                           admin_users=admin_user_list)  # Pass the list to HTML