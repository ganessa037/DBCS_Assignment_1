from flask import Blueprint, request, redirect, url_for, session, flash
from database import get_db_connection, get_user_role_name
from utils.security import get_client_ip

transaction_bp = Blueprint('transactions', __name__)

@transaction_bp.route('/transfer', methods=['POST'])
def transfer():
    if 'user_id' not in session: return redirect(url_for('auth.login'))
    
    # Only customers can transfer
    if session.get('role_id') != 2:
        flash("Unauthorized: Only customers can transfer money!", "error")
        return redirect(url_for('main.dashboard'))
    
    sender_id = session['user_id']
    receiver_acc_num = request.form.get('receiver_acc', '').strip()
    amount_str = request.form.get('amount', '').strip()
    
    # Validation
    if not receiver_acc_num:
        flash("Receiver Account Number is required!", "error")
        return redirect(url_for('main.dashboard'))
    
    try:
        amount = float(amount_str)
        if amount <= 0:
            flash("Amount must be greater than 0!", "error")
            return redirect(url_for('main.dashboard'))
    except ValueError:
        flash("Invalid amount format!", "error")
        return redirect(url_for('main.dashboard'))
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # Get Sender Account (use first account if multiple exist)
        cursor.execute("SELECT AccountID, Acc_Balance FROM Account WHERE UserID = ?", (sender_id,))
        sender_acc = cursor.fetchone()
        
        if not sender_acc:
            flash("Sender account not found!", "error")
            conn.close()
            return redirect(url_for('main.dashboard'))
        
        # Access pyodbc Row by index
        sender_account_id = sender_acc[0]
        sender_balance = float(sender_acc[1])
        
        if sender_balance < amount:
            flash(f"Insufficient Funds! Your balance is RM {sender_balance:.2f}", "error")
            conn.close()
            return redirect(url_for('main.dashboard'))
            
        # 2. Find Receiver Account
        cursor.execute("SELECT AccountID, Acc_Balance, UserID FROM Account WHERE Acc_Number = ?", (receiver_acc_num,))
        receiver_acc = cursor.fetchone()
        
        if not receiver_acc:
            flash(f"Receiver Account '{receiver_acc_num}' Not Found!", "error")
            conn.close()
            return redirect(url_for('main.dashboard'))
        
        receiver_account_id = receiver_acc[0]
        receiver_user_id = receiver_acc[2]
        
        # Prevent self-transfer
        if sender_account_id == receiver_account_id:
            flash("Cannot transfer to the same account!", "error")
            conn.close()
            return redirect(url_for('main.dashboard'))

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
        
    return redirect(url_for('main.dashboard'))

@transaction_bp.route('/deposit', methods=['POST'])
def deposit():
    if 'user_id' not in session: return redirect(url_for('auth.login'))
    
    # Only customers can deposit
    if session.get('role_id') != 2:
        flash("Unauthorized: Only customers can make deposits!", "error")
        return redirect(url_for('main.dashboard'))
    
    amount_str = request.form.get('amount', '').strip()
    
    # Validation
    try:
        amount = float(amount_str)
        if amount <= 0:
            flash("Amount must be greater than 0!", "error")
            return redirect(url_for('main.dashboard'))
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
            return redirect(url_for('main.dashboard'))
        
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
        
    return redirect(url_for('main.dashboard'))