from flask import Blueprint, request, redirect, url_for, session, flash
from database import get_db_connection, get_user_role_name
from extensions import role_required
from utils.security import get_client_ip

admin_bp = Blueprint('admin', __name__)

@admin_bp.route('/delete_user/<int:user_id>', methods=['POST'])
@role_required(3)
def delete_user(user_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # Check if user exists first
        cursor.execute("EXEC dbo.sp_GetUserById @UserID = ?", (user_id,))
        user_check = cursor.fetchone()

        if not user_check:
            flash(f"User ID {user_id} not found!", "error")
            conn.close()
            return redirect(url_for('main.dashboard'))
        
        actor_user_id = session['user_id']
        actor_user_name = session['user_name']
        actor_role_name = get_user_role_name(cursor, actor_user_id)
        actor_ip = get_client_ip()

        cursor.execute(
            "EXEC dbo.sp_DeleteUser @UserID = ?, @ActorUserID = ?, @ActorUserName = ?, @ActorRoleName = ?, @ActorIP = ?",
            (user_id, actor_user_id, actor_user_name, actor_role_name, actor_ip)
        )

        conn.commit()
        flash(f"User deleted successfully!", "success")

    except Exception as e:
        conn.rollback()
        print(e)
        flash("Failed to delete user. Please try again.", "error")
    finally:
        conn.close()
        
    return redirect(url_for('main.dashboard'))

@admin_bp.route('/update_role', methods=['POST'])
@role_required(1)
def update_role():
    target_user_id = request.form.get('user_id')
    new_role_id = request.form.get('new_role')
    new_status = request.form.get('status', 'Active')
    
    if not target_user_id or not new_role_id:
        flash("Missing required fields!", "error")
        return redirect(url_for('main.dashboard'))
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Check if user exists
    cursor.execute("EXEC dbo.sp_GetUserById @UserID = ?", (target_user_id,))
    user_check = cursor.fetchone()
    
    if not user_check:
        flash(f"User ID {target_user_id} not found!", "error")
        conn.close()
        return redirect(url_for('main.dashboard'))
    
    try:
        
        
        actor_user_id = session['user_id']
        actor_user_name = session['user_name']
        actor_role_name = get_user_role_name(cursor, actor_user_id)
        actor_ip = get_client_ip()

        cursor.execute(
            """
            EXEC dbo.sp_UpdateUserRoleAndStatus 
                @TargetUserID = ?, 
                @NewRoleID = ?, 
                @NewStatus = ?, 
                @ActorUserID = ?, 
                @ActorUserName = ?, 
                @ActorRoleName = ?, 
                @ActorIP = ?
            """,
            (target_user_id, new_role_id, new_status, actor_user_id, actor_user_name, actor_role_name, actor_ip)
        )

        conn.commit()
        flash("User updated successfully!", "success")

    except Exception as e:
        conn.rollback()
        flash(f"Failed to update user. Error: {str(e)}", "error")
    finally:
        conn.close()
        
    return redirect(url_for('main.dashboard'))