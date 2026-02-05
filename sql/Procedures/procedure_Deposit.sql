Use IronVaultDB;
Go

CREATE OR ALTER PROCEDURE dbo.sp_Deposit
    @UserID INT,
    @Amount DECIMAL(18,2),
    @ActorIP NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AccountID INT;
    DECLARE @UserName NVARCHAR(255);
    DECLARE @RoleName NVARCHAR(100);

    -- Get the user's account directly from the real table
    SELECT TOP 1 @AccountID = AccountID
    FROM Account
    WHERE UserID = @UserID
    ORDER BY AccountID;  -- deterministic if multiple accounts

    IF @AccountID IS NULL
        THROW 50001, 'Account not found.', 1;

    PRINT 'Debug: AccountID = ' + CAST(@AccountID AS NVARCHAR(10));

    -- Get user name and role
    SELECT @UserName = User_Name, @RoleName = r.Role_Name
    FROM [User] u
    JOIN [Role] r ON u.RoleID = r.RoleID
    WHERE u.UserID = @UserID;

    BEGIN TRANSACTION;

    BEGIN TRY
        -- Update balance
        UPDATE Account
        SET Acc_Balance = Acc_Balance + @Amount
        WHERE AccountID = @AccountID;

        -- Check update affected a row
        IF @@ROWCOUNT = 0
        BEGIN
            THROW 50002, 'Deposit failed: account not found or permission denied.', 1;
        END

        -- Record transaction
        INSERT INTO [Transaction] (ReceiverAccountID, Amount, Transaction_Type, Description)
        VALUES (@AccountID, @Amount, 'DEPOSIT', 'ATM Cash Deposit');

        -- Audit log
        INSERT INTO Application_Audit_Log 
            (UserID, User_Name, Role_Name, Action_Type, Status, Message, IP_Address)
        VALUES 
            (@UserID, @UserName, @RoleName, 'DEPOSIT', 'Success',
             CONCAT('Deposited RM ', FORMAT(@Amount, 'N2')), @ActorIP);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();

        -- Log failed deposit
        INSERT INTO Application_Audit_Log 
            (UserID, User_Name, Role_Name, Action_Type, Status, Message, IP_Address)
        VALUES 
            (@UserID, @UserName, @RoleName, 'DEPOSIT', 'Failed', @ErrorMsg, @ActorIP);

        THROW;
    END CATCH
END
GO

-- grant execute to flask
GRANT EXECUTE ON dbo.sp_Deposit TO db_app_service;

EXEC dbo.sp_Deposit @UserID = 22, @Amount = 50, @ActorIP = '127.0.0.1';
SELECT * FROM Account;

SELECT dp.name AS UserName,
       o.name AS ObjectName,
       p.permission_name,
       p.state_desc
FROM sys.database_principals dp
JOIN sys.database_permissions p
    ON dp.principal_id = p.grantee_principal_id
JOIN sys.objects o
    ON p.major_id = o.object_id
WHERE dp.name = 'transaction_service';

-- Allow updating account balances
GRANT UPDATE ON Account TO transaction_service;

-- Allow inserting transaction records
GRANT INSERT ON [Transaction] TO transaction_service;

-- Allow inserting into audit log
GRANT INSERT ON Application_Audit_Log TO transaction_service;

-- Optional: allow SELECT on User and Role tables for user info
GRANT SELECT ON [User] TO transaction_service;
GRANT SELECT ON [Role] TO transaction_service;