-- =============================================
-- DDM (Dynamic Data Masking) Setup
-- Masks sensitive data from unauthorized users
-- =============================================
-- Run this script in SSMS

USE IronVaultDB;
GO

-- Step 1: Add masking to User table

-- shows first and last letter of the name, mask the middle
ALTER TABLE [User]
ALTER COLUMN User_Name 
ADD MASKED WITH (FUNCTION = 'partial(1,"XXXX",1)');
GO

-- use default timestamp
ALTER TABLE [User]
ALTER COLUMN Last_Login ADD MASKED WITH (FUNCTION = 'default()');

-- step 2: add masking to account table
ALTER TABLE Account
ALTER COLUMN Acc_Balance ADD MASKED WITH (FUNCTION = 'default()');

-- step 3: add masking to transaction table
ALTER TABLE [Transaction]
ALTER COLUMN Amount ADD MASKED WITH (FUNCTION = 'default()');

-- step 4: add masking to application_audit_log table
ALTER TABLE Application_Audit_Log
ALTER COLUMN IP_Address ADD MASKED WITH (FUNCTION = 'default()');

-- unmask for db admin and dev
GRANT UNMASK TO db_dba;
GRANT UNMASK TO db_developer;

-- unmask for auditor on account balance
GRANT UNMASK 
ON OBJECT::dbo.Account(Acc_Balance)
TO db_auditor;

GRANT UNMASK 
ON OBJECT::dbo.[Transaction](Amount)
TO db_auditor;

-- test
EXEC sp_set_session_context @key = N'user_id', @value = 11;
EXEC sp_set_session_context @key = N'role_id', @value = 2;

EXECUTE AS USER='ironvault_app_user'
SELECT *
FROM dbo.[User]
REVERT;
