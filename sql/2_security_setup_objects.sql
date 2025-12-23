-- =============================================
-- Step 2: Setup security Objects
-- Include the creation of DMK, Cert, SMK
-- Best practice to backup them right away
-- Ensure 'C:\SQLBackups\' exists
-- =============================================

-- always make sure to use the correct database
USE IronVaultDB;
GO

-- database backup before security
-- difficult to trace if steps were wrong during security setup
BACKUP DATABASE IronVaultDB
TO DISK = 'C:\SQLBackups\IronVaultDB_full.bak'
WITH INIT, COMPRESSION;

-- DMK, encrypted using AES_256 algorithm 
CREATE MASTER KEY ENCRYPTION BY PASSWORD='Pa$$w0rd'

BACKUP MASTER KEY
TO FILE = 'C:\SQLBackups\IronVaultDB_DMK.bak'
ENCRYPTION BY PASSWORD = 'Pa$$w0rd';

RESTORE MASTER KEY 
FROM FILE = 'C:\SQLBackups\IronVaultDB_DMK.bak'
DECRYPTION BY PASSWORD = 'Pa$$w0rd'
ENCRYPTION BY PASSWORD = 'Pa$$w0rd';


-- certificate: create, backup, restore
CREATE CERTIFICATE IronVaultCert
WITH SUBJECT = 'IronVault Encryption Certificate';

BACKUP CERTIFICATE IronVaultCert
TO FILE = 'C:\SQLBackups\IronVaultCert.cer'
WITH PRIVATE KEY (
    FILE = 'C:\SQLBackups\IronVaultCert.pvk',
    ENCRYPTION BY PASSWORD = 'Pa$$w0rd'
);

CREATE CERTIFICATE IronVaultCert
FROM FILE = 'C:\SQLBackups\IronVaultCert.cer'
WITH PRIVATE KEY (
    FILE = 'C:\SQLBackups\IronVaultCert.pvk',
    DECRYPTION BY PASSWORD = 'Pa$$w0rd'
);


-- symmetric key: create, 
-- no need backup/restore since its saved inside cert
CREATE SYMMETRIC KEY IronVaultSymKey
WITH ALGORITHM = AES_256
ENCRYPTION BY CERTIFICATE IronVaultCert;

