from flask import Blueprint, render_template, request, redirect, url_for, session, flash
from database import get_db_connection, get_user_role_name
from utils.security import get_client_ip

main_bp = Blueprint('main', __name__)

@main_bp.route('/dashboard')
def dashboard():
    if 'user_id' not in session : return redirect(url_for('auth.login'))
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Variables
    my_accounts = []
    my_transactions = []
    all_customer_accounts = [] 
    security_logs = []       
    admin_user_list = []      # NEW: For Admin User Management
    
    role_id = session['role_id']
    
    # CUSTOMER DATA (Everyone gets this)
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

    # MANAGER DATA (Role 3)
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

    # ADMIN DATA (Role 1)
    if role_id == 1:
        # Get Security Logs
        cursor.execute("SELECT TOP 50 * FROM Audit_Log ORDER BY Action_Date DESC")
        security_logs = cursor.fetchall()
        
        # Get All Users for Management (NEW)
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