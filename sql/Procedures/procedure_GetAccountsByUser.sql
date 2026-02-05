USE IronVaultDB;
GO

-- reading account
ALTER PROCEDURE dbo.sp_GetAccountsByUser
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;

    OPEN SYMMETRIC KEY IronVaultSymKey
    DECRYPTION BY PASSWORD = 'Pa$$w0rd';

    SELECT 
        a.AccountID,
        a.UserID,
        u.User_Name,
        CONVERT(VARCHAR(20), DecryptByKey(a.Acc_Number_Encrypted)) AS Acc_Number,
        a.Acc_Balance
    FROM Account a
    INNER JOIN [User] u ON a.UserID = u.UserID 
    WHERE a.UserID = @UserID;

    CLOSE SYMMETRIC KEY IronVaultSymKey;
END;
GO

-- grant permission
GRANT EXECUTE ON dbo.sp_GetAccountsByUser TO db_app_service; 

-- to execute
EXEC dbo.sp_GetAccountsByUser 6;

