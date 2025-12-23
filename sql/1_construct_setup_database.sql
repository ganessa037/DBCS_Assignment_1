-- =============================================
-- Step 1: Database Creation Setup
-- Rebuild the database from scratch (no .bak)
-- =============================================

-- create database
CREATE DATABASE IronVaultDB;
GO

USE IronVaultDB;
GO

-- for simplicity, no schemas, straight go to the tables

-- Table 1: Role, the role is fixed for now
CREATE TABLE [Role] (
    RoleID INT PRIMARY KEY IDENTITY(1,1),
    Role_Name VARCHAR(100) NOT NULL UNIQUE
);
INSERT INTO [Role] (Role_Name) VALUES ('Admin');
INSERT INTO [Role] (Role_Name) VALUES ('Customer');
INSERT INTO [Role] (Role_Name) VALUES ('Manager');
GO

-- Table 2: User, with constraint that the email should be unique
-- SOX compliance, email is considered PII
CREATE TABLE [User] (
    UserID INT PRIMARY KEY IDENTITY(1,1),
    User_Name VARCHAR(255) NOT NULL,
    User_Email_Encrypted VARBINARY(MAX) NOT NULL,
    User_Email_Hash VARBINARY(32) NOT NULL,
    User_PasswordHash VARCHAR(500) NOT NULL,
    User_Salt VARCHAR(100) NOT NULL,
    Status VARCHAR(100) DEFAULT 'Active',
    RoleID INT FOREIGN KEY REFERENCES [Role](RoleID),
    Last_Login DATETIME DEFAULT NULL
);
ALTER TABLE [User]
ADD CONSTRAINT UQ_User_Email_Hash UNIQUE (User_Email_Hash);

-- Table 3: Account, with constraint that the account number must be unique
-- Financial account is decrypted, considered as PII in GDPR/PDPA
-- Ensure that the user id is unique, a one-to-one relation
CREATE TABLE Account (
    AccountID INT PRIMARY KEY IDENTITY(1,1),
    UserID INT FOREIGN KEY REFERENCES [User](UserID) ON DELETE CASCADE,
    Acc_Number_Encrypted VARBINARY(MAX) NOT NULL,
    Acc_Balance DECIMAL(18, 2) DEFAULT 0.00
);
ALTER TABLE Account
ADD Acc_Number_Hash AS HASHBYTES('SHA2_256', Acc_Number_Encrypted) PERSISTED;
ALTER TABLE Account
ADD CONSTRAINT UQ_AccNumber_Hash UNIQUE (Acc_Number_Hash);
ALTER TABLE Account
ADD CONSTRAINT UQ_UserID UNIQUE (UserID);

-- Table 4: Transaction
CREATE TABLE [Transaction] (
    TransactionID INT PRIMARY KEY IDENTITY(1,1),
    SenderAccountID INT FOREIGN KEY REFERENCES Account(AccountID),
    ReceiverAccountID INT FOREIGN KEY REFERENCES Account(AccountID),
    Amount DECIMAL(18, 2) NOT NULL,
    Transaction_Type VARCHAR(50) NOT NULL,
    Description VARCHAR(255),
    Transaction_Date DATETIME DEFAULT GETDATE()
);

-- Table 5: Application Audit Log records the action happening inside the flask
-- not the server
CREATE TABLE Application_Audit_Log (
    LogID INT PRIMARY KEY IDENTITY(1,1),
    UserID INT FOREIGN KEY REFERENCES [User](UserID),
    User_Name VARCHAR(255),
    Role_Name VARCHAR(100),
    Action_Type VARCHAR(255),
    Action_Date DATETIME DEFAULT GETDATE(),
    IP_Address VARCHAR(50),
    Status VARCHAR(100),
    Message VARCHAR(255)
);
GO