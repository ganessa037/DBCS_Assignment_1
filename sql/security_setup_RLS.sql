-- =============================================
-- RLS (Row-Level Security) Setup
-- Automatically filters rows based on user context
-- =============================================
-- Run this script in SSMS

USE IronVaultDB;
GO

-- Step 1: Create a function to check if user can access a row
-- This function will be used by the security policy
CREATE OR ALTER FUNCTION dbo.fn_security_predicate_user_account(@UserID AS INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN SELECT 1 AS access_result
WHERE 
    
    (IS_MEMBER('db_dba') = 1 OR IS_MEMBER('db_owner') = 1 OR IS_ROLEMEMBER('db_auditor') = 1 OR IS_ROLEMEMBER('db_developer') = 1)
    OR

    -- Admin (RoleID = 1) and Manager (RoleID = 3) can see all rows
    (CAST(SESSION_CONTEXT(N'role_id') AS INT) IN (1, 3))
    OR
    -- Customer (RoleID = 2) can only see their own data
    (CAST(SESSION_CONTEXT(N'user_id') AS INT) = @UserID);
GO

-- Step 2: Create security policy for Account table
-- This automatically filters rows based on the predicate function
IF EXISTS (SELECT * FROM sys.security_policies WHERE name = 'AccountSecurityPolicy')
BEGIN
    DROP SECURITY POLICY AccountSecurityPolicy;
    PRINT 'Existing AccountSecurityPolicy dropped.';
END
GO

CREATE SECURITY POLICY AccountSecurityPolicy
ADD FILTER PREDICATE dbo.fn_security_predicate_user_account(UserID)
ON dbo.Account
WITH (STATE = ON);
GO

-- Step 3: Create security policy for Transaction table
-- Customers can only see transactions involving their accounts
IF EXISTS (SELECT * FROM sys.security_policies WHERE name = 'TransactionSecurityPolicy')
BEGIN
    DROP SECURITY POLICY TransactionSecurityPolicy;
    PRINT 'Existing TransactionSecurityPolicy dropped.';
END
GO

CREATE OR ALTER FUNCTION dbo.fn_security_predicate_user_transaction(@SenderAccountID INT, @ReceiverAccountID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS access_result
    WHERE
        (IS_MEMBER('db_dba') = 1 OR IS_MEMBER('db_owner') = 1 OR IS_ROLEMEMBER('db_auditor') = 1 OR IS_ROLEMEMBER('db_developer') = 1)
        OR

        -- Admin/Manager see all
        (CAST(SESSION_CONTEXT(N'role_id') AS INT) IN (1, 3))
        OR
        -- Customer sees if they are sender or receiver
        EXISTS (
            SELECT 1
            FROM dbo.Account a
            WHERE a.UserID = CAST(SESSION_CONTEXT(N'user_id') AS INT)
            AND (a.AccountID = @SenderAccountID OR a.AccountID = @ReceiverAccountID)
        );
GO

CREATE SECURITY POLICY TransactionSecurityPolicy
ADD FILTER PREDICATE dbo.fn_security_predicate_user_transaction(SenderAccountID, ReceiverAccountID)
ON dbo.[Transaction]
WITH (STATE = ON);
GO

-- Create security policy for User table
-- Customers can only see their informations, admin see all
CREATE OR ALTER FUNCTION dbo.fn_security_predicate_user(@UserID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS access_result
    WHERE
        (IS_MEMBER('db_dba') = 1 OR IS_MEMBER('db_owner') = 1 OR IS_ROLEMEMBER('db_auditor') = 1 OR IS_ROLEMEMBER('db_developer') = 1)
        OR
        (CAST(SESSION_CONTEXT(N'role_id') AS INT) IN (1, 3))  -- Admin/Manager
        OR
        (CAST(SESSION_CONTEXT(N'user_id') AS INT) = @UserID); -- Customer
GO

CREATE SECURITY POLICY UserSecurityPolicy
ADD FILTER PREDICATE dbo.fn_security_predicate_user(UserID)
ON dbo.[User]
WITH (STATE = ON);
GO

-- Create security policy for application_log table
-- Customers can only see their informations, admin/manager see all
CREATE OR ALTER FUNCTION dbo.fn_security_predicate_audit_log(@UserID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS access_result
    WHERE
        (IS_MEMBER('db_dba') = 1 OR IS_MEMBER('db_owner') = 1 OR IS_ROLEMEMBER('db_auditor') = 1 OR IS_ROLEMEMBER('db_developer') = 1)
        OR

        (CAST(SESSION_CONTEXT(N'role_id') AS INT) IN (1, 3))  -- Admin/Manager
        OR
        (CAST(SESSION_CONTEXT(N'user_id') AS INT) = @UserID); -- Customer
GO

CREATE SECURITY POLICY ApplicationLogSecurityPolicy
ADD FILTER PREDICATE dbo.fn_security_predicate_audit_log(UserID)
ON dbo.Application_Audit_Log
WITH (STATE = ON);
GO

-- Step 4: Verify RLS is enabled
SELECT 
    name AS PolicyName,
    is_enabled,
    is_schema_bound,
    create_date
FROM sys.security_policies;
GO

SELECT 
    p.name AS PolicyName,
    o.name AS TableName,
    p.is_enabled
FROM sys.security_policies p
JOIN sys.objects o ON p.object_id = o.object_id;
GO

-- to execute
-- case 1: customer, only see theirs
EXEC sp_set_session_context @key = N'user_id', @value = 11;
EXEC sp_set_session_context @key = N'role_id', @value = 2;

-- case 2: admin, see all
EXEC sp_set_session_context @key = N'user_id', @value = 1;
EXEC sp_set_session_context @key = N'role_id', @value = 1;

SELECT * FROM dbo.[User];

SELECT * FROM dbo.[Transaction];

-- if done, clear it
EXEC sp_set_session_context @key = N'user_id', @value = NULL;
EXEC sp_set_session_context @key = N'role_id', @value = NULL;

-- verify current role
SELECT 
    'Current User' AS Info,
    USER_NAME() AS DatabaseUser,
    SYSTEM_USER AS LoginName; 