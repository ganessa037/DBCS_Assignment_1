from flask import Blueprint, request, redirect, url_for, session, flash
from database import get_db_connection, get_user_role_name
from utils.security import get_client_ip

admin_bp = Blueprint('admin', __name__)

@admin_bp.route('/delete_user/<int:user_id>', methods=['POST'])
def delete_user(user_id):
    if 'role_id' not in session or session['role_id'] != 3: # Only Manager can delete
        flash("Unauthorized Action!", "error")
        return redirect(url_for('main.dashboard'))
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # Check if user exists first
        cursor.execute("SELECT UserID, User_Name FROM [User] WHERE UserID = ?", (user_id,))
        user_check = cursor.fetchone()
        if not user_check:
            flash(f"User ID {user_id} not found!", "error")
            conn.close()
            return redirect(url_for('main.dashboard'))
        
        # Delete audit logs for this user (if foreign key exists)
        try:
            cursor.execute("DELETE FROM Audit_Log WHERE UserID = ?", (user_id,))
            audit_deleted = cursor.rowcount
        except:
            pass  # Ignore if table doesn't exist or no FK constraint
        
        # Delete their transactions first (Foreign Key Constraint)
        cursor.execute("DELETE FROM [Transaction] WHERE SenderAccountID IN (SELECT AccountID FROM Account WHERE UserID = ?) OR ReceiverAccountID IN (SELECT AccountID FROM Account WHERE UserID = ?)", (user_id, user_id))        
        
        # Delete their accounts
        cursor.execute("DELETE FROM Account WHERE UserID = ?", (user_id,))
        
        # Delete the user
        cursor.execute("DELETE FROM [User] WHERE UserID = ?", (user_id,))
        user_deleted = cursor.rowcount
        
        if user_deleted == 0:
            flash(f"Failed to delete user ID {user_id}. User may not exist.", "error")
            conn.rollback()
            conn.close()
            return redirect(url_for('main.dashboard'))
        
        conn.commit()
        
        # Log this action (Security Requirement) - Use session user info
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
    finally:
        conn.close()
        
    return redirect(url_for('main.dashboard'))

@admin_bp.route('/update_role', methods=['POST'])
def update_role():
    if 'role_id' not in session or session['role_id'] != 1:  # Strict Admin Check
        flash("Unauthorized!", "error")
        return redirect(url_for('main.dashboard'))
    
    target_user_id = request.form.get('user_id')
    new_role_id = request.form.get('new_role')
    new_status = request.form.get('status', 'Active')
    
    if not target_user_id or not new_role_id:
        flash("Missing required fields!", "error")
        return redirect(url_for('main.dashboard'))
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # Check if user exists
        cursor.execute("SELECT UserID, RoleID FROM [User] WHERE UserID = ?", (target_user_id,))
        user_check = cursor.fetchone()
        
        if not user_check:
            flash(f"User ID {target_user_id} not found!", "error")
            conn.close()
            return redirect(url_for('main.dashboard'))
        
        old_role_id = user_check[1]
        changes = []
        
        # Update the User's Role if changed
        if int(old_role_id) != int(new_role_id):
            cursor.execute("UPDATE [User] SET RoleID = ? WHERE UserID = ?", (new_role_id, target_user_id))
            role_names = {1: 'Admin', 2: 'Customer', 3: 'Manager'}
            old_role_name = role_names.get(int(old_role_id), 'Unknown')
            new_role_name = role_names.get(int(new_role_id), 'Unknown')
            changes.append(f"Role: {old_role_name} → {new_role_name}")
        
        # Update Status if Status column exists
        try:
            cursor.execute("UPDATE [User] SET Status = ? WHERE UserID = ?", (new_status, target_user_id))
            changes.append(f"Status: {new_status}")
        except:
            # Status column doesn't exist, skip
            pass
        
        if not changes:
            flash("No changes made!", "info")
            conn.close()
            return redirect(url_for('main.dashboard'))
        
        # Log it (Security Requirement)
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
    finally:
        conn.close()
        
    return redirect(url_for('main.dashboard'))