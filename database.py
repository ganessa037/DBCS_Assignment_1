import pyodbc
from flask import current_app

def get_db_connection():
    conn_str = (
        f'DRIVER={{ODBC Driver 17 for SQL Server}};' # this is the driver for the SQL Server, this is required to connect to the SQL Server
        f'SERVER={current_app.config['SERVER_NAME']};'
        f'DATABASE={current_app.config['DATABASE_NAME']};'
        f'Trusted_Connection=yes;'
    )
    return pyodbc.connect(conn_str)

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