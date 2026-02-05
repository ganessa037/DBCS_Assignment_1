USE IronVaultDB
GO

ALTER PROCEDURE dbo.sp_GetAllCustomerAccounts
AS
BEGIN
    SET NOCOUNT ON;
    
    OPEN SYMMETRIC KEY IronVaultSymKey
    DECRYPTION BY PASSWORD = 'Pa$$w0rd';

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
GO

GRANT EXECUTE ON dbo.sp_GetAllCustomerAccounts TO db_app_service;