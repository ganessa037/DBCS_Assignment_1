USE IronVaultDB;
GO

-- reading account
CREATE PROCEDURE dbo.sp_GetAccountsByUser
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;

    OPEN SYMMETRIC KEY IronVaultSymKey
    DECRYPTION BY CERTIFICATE IronVaultCert;

    SELECT 
        AccountID,
        UserID,
        CONVERT(VARCHAR(20), DecryptByKey(Acc_Number_Encrypted)) AS Acc_Number,
        Acc_Balance
    FROM Account
    WHERE UserID = @UserID;

    CLOSE SYMMETRIC KEY IronVaultSymKey;
END;

-- to execute
EXEC dbo.sp_GetAccountsByUser 12;

