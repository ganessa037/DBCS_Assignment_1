Use IronVaultDB
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetTransactionsByUser
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    
    OPEN SYMMETRIC KEY IronVaultSymKey
    DECRYPTION BY PASSWORD = 'Pa$$w0rd';
    
    SELECT 
        t.TransactionID,
        t.Transaction_Date,
        t.Transaction_Type,
        t.Amount,
        t.Description,
        t.SenderAccountID,
        t.ReceiverAccountID,
        CONVERT(VARCHAR(20), DECRYPTBYKEY(sa.Acc_Number_Encrypted)) AS SenderAccount,
        CONVERT(VARCHAR(20), DECRYPTBYKEY(ra.Acc_Number_Encrypted)) AS ReceiverAccount,
        su.User_Name AS SenderName,
        ru.User_Name AS ReceiverName,
        CASE 
            WHEN t.SenderAccountID IN (SELECT AccountID FROM Account WHERE UserID = @UserID) THEN 'Debit'
            ELSE 'Credit'
        END AS Transaction_Direction
    FROM [Transaction] t
    LEFT JOIN Account sa ON t.SenderAccountID = sa.AccountID
    LEFT JOIN Account ra ON t.ReceiverAccountID = ra.AccountID
    LEFT JOIN [User] su ON sa.UserID = su.UserID
    LEFT JOIN [User] ru ON ra.UserID = ru.UserID
    WHERE t.SenderAccountID IN (SELECT AccountID FROM Account WHERE UserID = @UserID)
       OR t.ReceiverAccountID IN (SELECT AccountID FROM Account WHERE UserID = @UserID)
    ORDER BY t.Transaction_Date DESC;
    
    CLOSE SYMMETRIC KEY IronVaultSymKey;
END;
GO

GRANT EXECUTE ON dbo.sp_GetTransactionsByUser TO db_app_service;
