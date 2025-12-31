from flask import Blueprint, request, redirect, url_for, session, flash
from database import get_db_connection, get_user_role_name
from utils.security import get_client_ip
from extensions import role_required

transaction_bp = Blueprint('transactions', __name__)

@transaction_bp.route('/transfer', methods=['POST'])
@role_required(2)
def transfer():
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
        cursor.execute(
            "EXEC dbo.sp_TransferFunds @SenderUserID = ?, @ReceiverAccNumber = ?, @Amount = ?, @ActorIP = ?",
            (sender_id, receiver_acc_num, amount, get_client_ip())
        )
        conn.commit()
        flash(f"Successfully transferred RM {amount:.2f} to account {receiver_acc_num}!", "success")
        
    except Exception as e:
        conn.rollback()
        flash(f"Transfer failed: {str(e)}", "error")
    finally:
        conn.close()
        
    return redirect(url_for('main.dashboard'))

@transaction_bp.route('/deposit', methods=['POST'])
@role_required(2)
def deposit():
    
    amount_str = request.form.get('amount', '').strip()
    
    # Validation
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
        cursor.execute(
            "EXEC dbo.sp_Deposit @UserID = ?, @Amount = ?, @ActorIP = ?",
            (session['user_id'], amount, get_client_ip())
        )
        conn.commit()
        flash(f"Successfully deposited RM {amount:.2f}!", "success")
        
    except Exception as e:
        conn.rollback()
        flash(f"Deposit failed: {str(e)}", "error")
    finally:
        conn.close()
        
    return redirect(url_for('main.dashboard'))


@transaction_bp.route('/debug-balance-check')
def debug_balance_check():
    from flask import jsonify
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        
        # Query 2: Check what SESSION_CONTEXT sees
        cursor.execute("""
            SELECT 
                CAST(SESSION_CONTEXT(N'user_id') AS INT) AS ContextUserID,
                CAST(SESSION_CONTEXT(N'role_id') AS INT) AS ContextRoleID
        """)
        context = cursor.fetchone()
        
        return jsonify({
            "flask_session_user_id": session.get('user_id'),
            "flask_session_role_id": session.get('role_id'),
            "db_context_user_id": context[0] if context else None,
            "db_context_role_id": context[1] if context else None,
            "rls_working": context[0] == session.get('user_id')
        })
        
    finally:
        cursor.close()
        conn.close()