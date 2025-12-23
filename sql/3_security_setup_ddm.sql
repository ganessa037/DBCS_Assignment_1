-- =============================================
-- Step 3: DDM (Dynamic Data Masking) Setup
-- Masks sensitive data from unauthorized users
-- =============================================

USE IronVaultDB;
GO

-- shows the first 2 letters, others ***
ALTER TABLE [User]
ALTER COLUMN User_Name ADD MASKED WITH (FUNCTION = 'partial(2,"****",0)');
GO

-- use default masking timestamp
ALTER TABLE [User]
ALTER COLUMN Last_Login ADD MASKED WITH (FUNCTION = 'default()');

-- add masking to account table
ALTER TABLE Account
ALTER COLUMN Acc_Balance ADD MASKED WITH (FUNCTION = 'default()');

-- add masking to transaction table
ALTER TABLE [Transaction]
ALTER COLUMN Amount ADD MASKED WITH (FUNCTION = 'default()');

-- add masking to application_audit_log table
ALTER TABLE Application_Audit_Log
ALTER COLUMN IP_Address ADD MASKED WITH (FUNCTION = 'partial(10,"xxx",0)');