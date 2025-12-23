Use IronVaultDB;
Go

CREATE OR ALTER PROCEDURE dbo.sp_Deposit
    @UserID INT,
    @Amount DECIMAL(18,2),
    @ActorIP NVARCHAR(50)
WITH EXECUTE AS 'transaction_service'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AccountID INT;
    DECLARE @UserName NVARCHAR(255);
    DECLARE @RoleName NVARCHAR(100);

    -- Get user's account (first account)
    SELECT TOP 1 @AccountID = AccountID
    FROM vw_Account
    WHERE UserID = @UserID;

    IF @AccountID IS NULL
        THROW 50001, 'Account not found.', 1;

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

        -- Record transaction
        INSERT INTO [Transaction] (ReceiverAccountID, Amount, Transaction_Type, Description)
        VALUES (@AccountID, @Amount, 'DEPOSIT', 'ATM Cash Deposit');

        -- Audit log
        INSERT INTO Application_Audit_Log (UserID, User_Name, Role_Name, Action_Type, Status, Message, IP_Address)
        VALUES (@UserID, @UserName, @RoleName, 'DEPOSIT', 'Success',
                CONCAT('Deposited RM ', FORMAT(@Amount, 'N2')), @ActorIP);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();

        -- Log failed deposit
        INSERT INTO Application_Audit_Log (UserID, User_Name, Role_Name, Action_Type, Status, Message, IP_Address)
        VALUES (@UserID, @UserName, @RoleName, 'DEPOSIT', 'Failed', @ErrorMsg, @ActorIP);

        THROW;
    END CATCH
END
GO

-- grant execute to flask
GRANT EXECUTE ON dbo.sp_Deposit TO db_app_service;