Use IronVaultDB
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetTransactionsByUser
    @UserID INT
WITH EXECUTE AS 'transaction_service'
AS
BEGIN
    SET NOCOUNT ON;
    
    OPEN SYMMETRIC KEY IronVaultSymKey
    DECRYPTION BY CERTIFICATE IronVaultCert;
    
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

CREATE OR ALTER PROCEDURE dbo.sp_GetAllCustomerAccounts
WITH EXECUTE AS 'transaction_service'
AS
BEGIN
    SET NOCOUNT ON;
    
    OPEN SYMMETRIC KEY IronVaultSymKey
    DECRYPTION BY CERTIFICATE IronVaultCert;

    SELECT 
        u.UserID, 
        CASE 
            WHEN LEN(u.User_Name) <= 2 THEN u.User_Name
            ELSE LEFT(u.User_Name, 2) + REPLICATE('*', LEN(u.User_Name) - 2)
        END AS User_Name,
        CASE 
            WHEN CONVERT(VARCHAR(255), DECRYPTBYKEY(User_Email_Encrypted)) IS NOT NULL 
                AND CHARINDEX('@', CONVERT(VARCHAR(255), DECRYPTBYKEY(User_Email_Encrypted))) > 0 
            THEN 
                LEFT(CONVERT(VARCHAR(255), DECRYPTBYKEY(User_Email_Encrypted)), 1) + 
                REPLICATE('*', CHARINDEX('@', CONVERT(VARCHAR(255), DECRYPTBYKEY(User_Email_Encrypted))) - 2) + 
                SUBSTRING(
                    CONVERT(VARCHAR(255), DECRYPTBYKEY(User_Email_Encrypted)), 
                    CHARINDEX('@', CONVERT(VARCHAR(255), DECRYPTBYKEY(User_Email_Encrypted))), 
                    LEN(CONVERT(VARCHAR(255), DECRYPTBYKEY(User_Email_Encrypted)))
                )
            ELSE 
                '[PROTECTED]'
        END AS User_Email,
        CONVERT(VARCHAR(20), DecryptByKey(a.Acc_Number_Encrypted)) AS Acc_Number, 
        a.Acc_Balance
    FROM Account a
    JOIN [User] u ON a.UserID = u.UserID
    JOIN [Role] r ON u.RoleID = r.RoleID
    WHERE r.Role_Name = 'Customer';
    CLOSE SYMMETRIC KEY IronVaultSymKey;
END;

CREATE OR ALTER PROCEDURE dbo.sp_GetAllUsers
WITH EXECUTE AS 'transaction_service'
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Open the symmetric key for decryption
    OPEN SYMMETRIC KEY IronVaultSymKey
    DECRYPTION BY CERTIFICATE IronVaultCert;
    
    SELECT 
        u.UserID,
        -- Mask name: Show first 2 chars, rest as asterisks (e.g., "Natasha" -> "Na*****")
        CASE 
            WHEN LEN(u.User_Name) <= 2 THEN u.User_Name
            ELSE LEFT(u.User_Name, 2) + REPLICATE('*', LEN(u.User_Name) - 2)
        END AS User_Name,
        -- Mask email: Show first char and domain, hide the rest (e.g., "test@example.com" -> "t***@example.com")
        CASE 
            WHEN CONVERT(VARCHAR(255), DECRYPTBYKEY(User_Email_Encrypted)) IS NOT NULL 
                AND CHARINDEX('@', CONVERT(VARCHAR(255), DECRYPTBYKEY(User_Email_Encrypted))) > 0 
            THEN 
                LEFT(CONVERT(VARCHAR(255), DECRYPTBYKEY(User_Email_Encrypted)), 1) + 
                REPLICATE('*', CHARINDEX('@', CONVERT(VARCHAR(255), DECRYPTBYKEY(User_Email_Encrypted))) - 2) + 
                SUBSTRING(
                    CONVERT(VARCHAR(255), DECRYPTBYKEY(User_Email_Encrypted)), 
                    CHARINDEX('@', CONVERT(VARCHAR(255), DECRYPTBYKEY(User_Email_Encrypted))), 
                    LEN(CONVERT(VARCHAR(255), DECRYPTBYKEY(User_Email_Encrypted)))
                )
            ELSE 
                '[PROTECTED]'
        END AS User_Email,
        r.Role_Name, 
        u.RoleID,
        ISNULL(u.Status, 'Active') AS Status
    FROM [User] u
    JOIN [Role] r ON u.RoleID = r.RoleID;
    
    -- Close the symmetric key
    CLOSE SYMMETRIC KEY IronVaultSymKey;
END;
GO


CREATE OR ALTER PROCEDURE dbo.sp_GetAuditLogs
    @Top INT = 50
WITH EXECUTE AS 'transaction_service'  -- This user has UNMASK permission
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@Top) 
        LogID,
        UserID,
        User_Name,
        Role_Name,
        Action_Type,
        Status,
        Message,
        Action_Date,
        -- Mask last octet: 192.168.1.100 becomes 192.168.1.xxx
        CASE 
            WHEN IP_Address IS NOT NULL AND IP_Address LIKE '%.%.%.%' THEN
                SUBSTRING(IP_Address, 1, LEN(IP_Address) - CHARINDEX('.', REVERSE(IP_Address))) + '.xxx'
            ELSE 
                IP_Address
        END AS IP_Address
    FROM Application_Audit_Log
    ORDER BY Action_Date DESC;
END;
GO
