CREATE DATABASE IronVaultDB;
GO

USE IronVaultDB;
GO

-- 3. Create Tables

-- Table: Role
CREATE TABLE [Role] (
    RoleID INT PRIMARY KEY IDENTITY(1,1),
    Role_Name VARCHAR(100) NOT NULL UNIQUE
);

-- Table: User
CREATE TABLE [User] (
    UserID INT PRIMARY KEY IDENTITY(1,1),
    User_Name VARCHAR(255) NOT NULL,
    User_Email VARCHAR(255) UNIQUE NOT NULL,
    User_PasswordHash VARCHAR(500) NOT NULL,
    User_Salt VARCHAR(100) NOT NULL,
    Status VARCHAR(100) DEFAULT 'Active',
    RoleID INT FOREIGN KEY REFERENCES [Role](RoleID),
    Last_Login DATETIME DEFAULT NULL
);

-- Table: Account
CREATE TABLE Account (
    AccountID INT PRIMARY KEY IDENTITY(1,1),
    UserID INT FOREIGN KEY REFERENCES [User](UserID) ON DELETE CASCADE,
    Acc_Number VARCHAR(20) UNIQUE NOT NULL,
    Acc_Balance DECIMAL(18, 2) DEFAULT 0.00
);

-- Table: Transaction
CREATE TABLE [Transaction] (
    TransactionID INT PRIMARY KEY IDENTITY(1,1),
    SenderAccountID INT FOREIGN KEY REFERENCES Account(AccountID),
    ReceiverAccountID INT FOREIGN KEY REFERENCES Account(AccountID),
    Amount DECIMAL(18, 2) NOT NULL,
    Transaction_Type VARCHAR(50) NOT NULL,
    Description VARCHAR(255),
    Transaction_Date DATETIME DEFAULT GETDATE()
);

-- Table: Audit_Log
CREATE TABLE Audit_Log (
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

-- 4. Insert Default Roles
INSERT INTO [Role] (Role_Name) VALUES ('Admin');
INSERT INTO [Role] (Role_Name) VALUES ('Customer');
INSERT INTO [Role] (Role_Name) VALUES ('Manager');
GO

PRINT 'IronVaultDB has been successfully reset and recreated!';
