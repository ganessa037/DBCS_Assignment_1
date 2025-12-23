USE IronVaultDB;
GO
CREATE OR ALTER PROCEDURE dbo.sp_TransferFunds
    @SenderUserID INT,
    @ReceiverAccNumber NVARCHAR(50),
    @Amount DECIMAL(18,2),
    @ActorIP NVARCHAR(50)
WITH EXECUTE AS 'transaction_service'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @SenderAccountID INT, @SenderBalance DECIMAL(18,2);
    DECLARE @ReceiverAccountID INT, @ReceiverUserID INT;
    DECLARE @SenderName NVARCHAR(255);
    DECLARE @RoleName NVARCHAR(100);
    
    BEGIN TRY
        OPEN SYMMETRIC KEY IronVaultSymKey
        DECRYPTION BY CERTIFICATE IronVaultCert;
        
        -- Get sender account and balance
        SELECT TOP 1 
            @SenderAccountID = AccountID, 
            @SenderBalance = Acc_Balance
        FROM vw_Account
        WHERE UserID = @SenderUserID;
        
        IF @SenderAccountID IS NULL
        BEGIN
            CLOSE SYMMETRIC KEY IronVaultSymKey;
            THROW 50001, 'Sender account not found.', 1;
        END
        
        IF @SenderBalance < @Amount
        BEGIN
            CLOSE SYMMETRIC KEY IronVaultSymKey;
            THROW 50002, 'Insufficient funds.', 1;
        END
        
        -- Get receiver account - using VARCHAR for decryption (CRITICAL FIX)
        SELECT TOP 1 
            @ReceiverAccountID = AccountID, 
            @ReceiverUserID = UserID
        FROM Account
        WHERE CONVERT(VARCHAR(50), DECRYPTBYKEY(Acc_Number_Encrypted)) = @ReceiverAccNumber;
        
        CLOSE SYMMETRIC KEY IronVaultSymKey;
        
        IF @ReceiverAccountID IS NULL
            THROW 50003, 'Receiver account not found.', 1;
        
        IF @SenderAccountID = @ReceiverAccountID
            THROW 50004, 'Cannot transfer to the same account.', 1;
        
        -- Get sender name and role
        SELECT @SenderName = User_Name, @RoleName = r.Role_Name
        FROM [User] u
        JOIN [Role] r ON u.RoleID = r.RoleID
        WHERE u.UserID = @SenderUserID;
        
        BEGIN TRANSACTION;
        
        UPDATE Account
        SET Acc_Balance = Acc_Balance - @Amount
        WHERE AccountID = @SenderAccountID;
        
        UPDATE Account
        SET Acc_Balance = Acc_Balance + @Amount
        WHERE AccountID = @ReceiverAccountID;
        
        INSERT INTO [Transaction] (SenderAccountID, ReceiverAccountID, Amount, Transaction_Type, Description)
        VALUES (@SenderAccountID, @ReceiverAccountID, @Amount, 'TRANSFER', 'Online Transfer');
        
        INSERT INTO Application_Audit_Log (UserID, User_Name, Role_Name, Action_Type, Status, Message, IP_Address)
        VALUES (@SenderUserID, @SenderName, @RoleName, 'TRANSFER', 'Success', 
                CONCAT('Transferred RM ', FORMAT(@Amount, 'N2'), ' to account ', @ReceiverAccNumber), @ActorIP);
        
        COMMIT TRANSACTION;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        IF (SELECT COUNT(*) FROM sys.openkeys WHERE key_name = 'IronVaultSymKey') > 0
            CLOSE SYMMETRIC KEY IronVaultSymKey;
            
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        INSERT INTO Application_Audit_Log (UserID, User_Name, Role_Name, Action_Type, Status, Message, IP_Address)
        VALUES (@SenderUserID, ISNULL(@SenderName, 'Unknown'), ISNULL(@RoleName, 'Unknown'), 
                'TRANSFER', 'Failed', @ErrorMsg, @ActorIP);
        
        THROW;
    END CATCH
END
GO