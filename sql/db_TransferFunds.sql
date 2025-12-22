Use IronVaultDB;
GO

CREATE OR ALTER PROCEDURE dbo.sp_TransferFunds
    @SenderUserID INT,
    @ReceiverAccNumber NVARCHAR(50),
    @Amount DECIMAL(18,2),
    @ActorIP NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SenderAccountID INT, @SenderBalance DECIMAL(18,2);
    DECLARE @ReceiverAccountID INT, @ReceiverUserID INT;
    DECLARE @SenderName NVARCHAR(255);
    DECLARE @RoleName NVARCHAR(100);

    -- Get sender account and balance
    SELECT TOP 1 
        @SenderAccountID = AccountID, 
        @SenderBalance = Acc_Balance
    FROM vw_Account
    WHERE UserID = @SenderUserID;

    IF @SenderAccountID IS NULL
        THROW 50001, 'Sender account not found.', 1;

    IF @SenderBalance < @Amount
        THROW 50002, 'Insufficient funds.', 1;

    -- Get receiver account
    SELECT TOP 1 
        @ReceiverAccountID = AccountID, 
        @ReceiverUserID = UserID
    FROM vw_Account
    WHERE Acc_Number = @ReceiverAccNumber;

    IF @ReceiverAccountID IS NULL
        THROW 50003, 'Receiver account not found.', 1;

    -- Prevent self-transfer
    IF @SenderAccountID = @ReceiverAccountID
        THROW 50004, 'Cannot transfer to the same account.', 1;

    -- Get sender name and role
    SELECT @SenderName = User_Name, @RoleName = r.Role_Name
    FROM [User] u
    JOIN [Role] r ON u.RoleID = r.RoleID
    WHERE u.UserID = @SenderUserID;

    BEGIN TRANSACTION;

    BEGIN TRY
        -- Deduct from sender
        UPDATE Account
        SET Acc_Balance = Acc_Balance - @Amount
        WHERE AccountID = @SenderAccountID;

        -- Add to receiver
        UPDATE Account
        SET Acc_Balance = Acc_Balance + @Amount
        WHERE AccountID = @ReceiverAccountID;

        -- Record the transaction
        INSERT INTO [Transaction] (SenderAccountID, ReceiverAccountID, Amount, Transaction_Type, Description)
        VALUES (@SenderAccountID, @ReceiverAccountID, @Amount, 'TRANSFER', 'Online Transfer');

        -- Log success
        INSERT INTO Application_Audit_Log (UserID, User_Name, Role_Name, Action_Type, Status, Message, IP_Address)
        VALUES (@SenderUserID, @SenderName, @RoleName, 'TRANSFER', 'Success', 
                CONCAT('Transferred RM ', FORMAT(@Amount, 'N2'), ' to account ', @ReceiverAccNumber), @ActorIP);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        INSERT INTO Application_Audit_Log (UserID, User_Name, Role_Name, Action_Type, Status, Message, IP_Address)
        VALUES (@SenderUserID, @SenderName, @RoleName, 'TRANSFER', 'Failed', @ErrorMsg, @ActorIP);

        THROW; -- re-throw the error
    END CATCH
END
GO
