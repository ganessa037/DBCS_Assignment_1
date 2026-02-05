import pyodbc
from flask import current_app, session

def get_db_connection():
    conn_str = (
        f"DRIVER={{ODBC Driver 18 for SQL Server}};" # this is the driver for the SQL Server, this is required to connect to the SQL Server
        f"SERVER={current_app.config['SERVER_NAME']};"
        f"DATABASE={current_app.config['DATABASE_NAME']};"
        f"UID={current_app.config['USERNAME']};"
        f"PWD={current_app.config['DB_PASSWORD']};"
        "TrustServerCertificate=yes;"
        "Encrypt=yes;"  # Enable SSL/TLS encryption in transit
    )
    conn = pyodbc.connect(conn_str)
    
    # SECURITY: Set RLS session context if user is logged in
    # This enables Row-Level Security to automatically filter rows
    if 'user_id' in session and 'role_id' in session:
        try:
            cursor = conn.cursor()
            set_rls_session_context(cursor, session['user_id'], session['role_id'])
            cursor.close()
        except:
            # If RLS is not configured, continue without it
            pass
    
    return conn

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
    
def set_rls_session_context(cursor, user_id, role_id):
    """
    Set session context for Row-Level Security (RLS)
    This tells SQL Server who the current user is so RLS can filter rows automatically
    """
    try:
        cursor.execute("EXEC sp_set_session_context @key = N'user_id', @value = ?", (user_id,))
        cursor.execute("EXEC sp_set_session_context @key = N'role_id', @value = ?", (role_id,))
    except Exception as e:
        # If RLS is not configured, this will fail silently
        # This allows the app to work even if RLS scripts haven't been run yet
        print(f"RLS session context not set (this is OK if RLS is not configured): {e}")
        pass

def clear_rls_session_context(cursor):
    """
    Clear SQL Server session context (used for Row-Level Security)
    """
    try:
        cursor.execute(
            "EXEC sp_set_session_context @key = N'user_id', @value = NULL"
        )
        cursor.execute(
            "EXEC sp_set_session_context @key = N'role_id', @value = NULL"
        )
    except Exception as e:
        print(f"RLS session context not cleared (safe to ignore): {e}")
        pass