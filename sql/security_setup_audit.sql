-- =============================================
-- SQL Server Audit Setup
-- Server-level audit logging for compliance
-- =============================================
-- Run this script in SSMS as Administrator

USE master;
GO

-- Step 1: Create Server Audit
-- This defines where audit logs will be stored
IF EXISTS (SELECT * FROM sys.database_audit_specifications 
           WHERE name = 'IronVault_DB_Audit_Spec')
BEGIN
    USE IronVaultDB;
    ALTER DATABASE AUDIT SPECIFICATION IronVault_DB_Audit_Spec WITH (STATE = OFF);
    DROP DATABASE AUDIT SPECIFICATION IronVault_DB_Audit_Spec;
END
GO

USE master;
GO

-- Drop existing audit (if exists)
IF EXISTS (SELECT * FROM sys.server_audits WHERE name = 'IronVault_Server_Audit')
BEGIN
    ALTER SERVER AUDIT IronVault_Server_Audit WITH (STATE = OFF);
    DROP SERVER AUDIT IronVault_Server_Audit;
END
GO

-- Create audit file location (adjust path as needed)
-- Make sure the folder exists and SQL Server has write permissions
CREATE SERVER AUDIT IronVault_Server_Audit
TO FILE (
    FILEPATH = 'C:\SQLAudit\IronVault\',
    MAXSIZE = 100 MB,
    MAX_ROLLOVER_FILES = 10,
    RESERVE_DISK_SPACE = OFF
)
WITH (
    QUEUE_DELAY = 1000,
    ON_FAILURE = CONTINUE
);
GO

-- Enable the audit
ALTER SERVER AUDIT IronVault_Server_Audit WITH (STATE = ON);
GO

-- Create Server Audit Specification for login events
IF EXISTS (SELECT * FROM sys.server_audit_specifications 
           WHERE name = 'IronVault_Server_Audit_Spec')
BEGIN
    ALTER SERVER AUDIT SPECIFICATION IronVault_Server_Audit_Spec WITH (STATE = OFF);
    DROP SERVER AUDIT SPECIFICATION IronVault_Server_Audit_Spec;
END
GO

CREATE SERVER AUDIT SPECIFICATION IronVault_Server_Audit_Spec
FOR SERVER AUDIT IronVault_Server_Audit
ADD (FAILED_LOGIN_GROUP),
ADD (SUCCESSFUL_LOGIN_GROUP)
WITH (STATE = ON);
GO

-- Step 2: Create Database Audit Specification
-- This defines what events to audit in IronVaultDB
USE IronVaultDB;
GO

IF EXISTS (SELECT * FROM sys.database_audit_specifications 
           WHERE name = 'IronVault_DB_Audit_Spec')
BEGIN
    ALTER DATABASE AUDIT SPECIFICATION IronVault_DB_Audit_Spec WITH (STATE = OFF);
    DROP DATABASE AUDIT SPECIFICATION IronVault_DB_Audit_Spec;
END
GO

CREATE DATABASE AUDIT SPECIFICATION IronVault_DB_Audit_Spec
FOR SERVER AUDIT IronVault_Server_Audit
-- Application activity
ADD (SELECT, INSERT, UPDATE, DELETE ON OBJECT::[dbo].[User]        BY [db_app_service]),
ADD (SELECT, INSERT, UPDATE, DELETE ON OBJECT::[dbo].[Account]     BY [db_app_service]),
ADD (SELECT, INSERT, UPDATE, DELETE ON OBJECT::[dbo].[Transaction] BY [db_app_service]),
-- Developer activity
ADD (SELECT, INSERT, UPDATE, DELETE ON OBJECT::[dbo].[User]    BY [db_developer]),
ADD (SELECT, INSERT, UPDATE, DELETE ON OBJECT::[dbo].[Account] BY [db_developer]),
-- Audit log access (auditor only)
ADD (SELECT ON OBJECT::[dbo].[Application_Audit_Log] BY [db_auditor]),
-- Structural & permission changes
ADD (DATABASE_PERMISSION_CHANGE_GROUP),
ADD (SCHEMA_OBJECT_CHANGE_GROUP)
WITH (STATE = ON);
GO

-- Step 3: Verify Audit Status
USE master;
GO

SELECT 
    name AS AuditName,
    is_state_enabled,
    create_date,
    type_desc
FROM sys.server_audits
WHERE name = 'IronVault_Server_Audit';

SELECT 
    name AS ServerAuditSpecName,
    is_state_enabled,
    create_date
FROM sys.server_audit_specifications
WHERE name = 'IronVault_Server_Audit_Spec';

USE IronVaultDB;
GO

SELECT 
    name AS DatabaseAuditSpecName,
    is_state_enabled,
    create_date
FROM sys.database_audit_specifications
WHERE name = 'IronVault_DB_Audit_Spec';
GO

PRINT '=============================================';
PRINT 'SQL Server Audit Setup Complete!';
PRINT 'Configured database access is now being logged.';
PRINT 'Audit files location: C:\SQLAudit\IronVault\';
PRINT '=============================================';

-- Step 4: View Audit Logs (Example query)
-- Note: Ensure the path exists and has audit files before running
USE master;
GO

SELECT 
    event_time,
    action_id,
    succeeded,
    server_principal_name,
    database_name,
    schema_name,
    object_name,
    statement
FROM fn_get_audit_file('C:\SQLAudit\IronVault\*.sqlaudit', DEFAULT, DEFAULT)
ORDER BY event_time DESC;