-- =============================================
-- TDE (Transparent Data Encryption) Setup
-- Encrypts database files at rest
-- =============================================
-- Run this script in SSMS as Administrator
-- Requires SQL Server Developer/Enterprise Edition

USE master;
GO

-- Step 1: Create Master Key (if not exists)
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Pa$$w0rd';
    PRINT 'Master Key created successfully.';
END
ELSE
BEGIN
    PRINT 'Master Key already exists.';
END
GO

-- Step 2: Create Certificate for TDE
USE master;
GO

IF NOT EXISTS (SELECT * FROM sys.certificates WHERE name = 'IronVault_TDE_Certificate')
BEGIN
    CREATE CERTIFICATE IronVault_TDE_Certificate
    WITH SUBJECT = 'IronVault TDE Certificate';
    PRINT 'TDE Certificate created successfully.';
END
ELSE
BEGIN
    PRINT 'TDE Certificate already exists.';
END
GO

-- Step 3: Enable TDE on IronVaultDB
USE IronVaultDB;
GO

-- Check if TDE is already enabled
IF NOT EXISTS (SELECT * FROM sys.dm_database_encryption_keys WHERE database_id = DB_ID('IronVaultDB'))
BEGIN
    -- Create Database Encryption Key
    CREATE DATABASE ENCRYPTION KEY
    WITH ALGORITHM = AES_256
    ENCRYPTION BY SERVER CERTIFICATE IronVault_TDE_Certificate;
    
    PRINT 'Database Encryption Key created.';
    
    -- Enable TDE
    ALTER DATABASE IronVaultDB
    SET ENCRYPTION ON;
    
    PRINT 'TDE enabled on IronVaultDB.';
    PRINT 'Note: Encryption may take some time to complete. Check status with:';
    PRINT 'SELECT encryption_state, encryption_state_desc FROM sys.dm_database_encryption_keys WHERE database_id = DB_ID(''IronVaultDB'');';
END
ELSE
BEGIN
    PRINT 'TDE is already enabled on IronVaultDB.';
END
GO

-- Step 4: Verify TDE Status
SELECT 
    DB_NAME(database_id) AS DatabaseName,
    encryption_state,
    CASE encryption_state
        WHEN 0 THEN 'No encryption'
        WHEN 1 THEN 'Unencrypted'
        WHEN 2 THEN 'Encryption in progress'
        WHEN 3 THEN 'Encrypted'
        WHEN 4 THEN 'Key change in progress'
        WHEN 5 THEN 'Decryption in progress'
        WHEN 6 THEN 'Protection change in progress'
    END AS EncryptionStateDesc,
    encryption_scan_state,
    encryption_scan_modify_date,
    key_algorithm,
    key_length
FROM sys.dm_database_encryption_keys
WHERE database_id = DB_ID('IronVaultDB');
GO

PRINT '=============================================';
PRINT 'TDE Setup Complete!';
PRINT 'Database files are now encrypted at rest.';
PRINT 'Backups will also be encrypted automatically.';
PRINT '=============================================';

-- backup master key and certs
USE master;
GO

BACKUP MASTER KEY
TO FILE = 'C:\SQLBackups\Master_DMK.bak'
ENCRYPTION BY PASSWORD = 'Pa$$w0rd';
GO

BACKUP CERTIFICATE IronVault_TDE_Certificate
TO FILE = 'C:\SQLBackups\IronVault_TDE_Cert.cer'
WITH PRIVATE KEY (
    FILE = 'C:\SQLBackups\IronVault_TDE_PrivateKey.pvk',
    ENCRYPTION BY PASSWORD = 'Pa$$w0rd'
);
GO