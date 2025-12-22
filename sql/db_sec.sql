
USE IronVaultDB;
GO

-- database backup
BACKUP DATABASE IronVaultDB
TO DISK = 'C:\SQLBackups\IronVaultDB_full.bak'
WITH INIT, COMPRESSION;

-- master key : create, backup, restore
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

-- symmetric key: create, no need backup/restore since its saved inside cert
CREATE SYMMETRIC KEY IronVaultSymKey
WITH ALGORITHM = AES_256
ENCRYPTION BY CERTIFICATE IronVaultCert;


-- encrypt the account number, no need to re-run unless for demo or alter
ALTER TABLE Account
ADD Acc_Number_Encrypted VARBINARY(MAX);

OPEN SYMMETRIC KEY IronVaultSymKey
DECRYPTION BY CERTIFICATE IronVaultCert;

UPDATE Account
SET Acc_Number_Encrypted = EncryptByKey(
    Key_GUID('IronVaultSymKey'),
    CONVERT(varbinary, Acc_Number)
);

-- encrypt the email
ALTER TABLE [User]
ADD User_Email_Encrypted VARBINARY(MAX);

UPDATE [User]
SET User_Email_Encrypted = EncryptByKey(
    Key_GUID('IronVaultSymKey'),
    CONVERT(varbinary, User_Email)
);

