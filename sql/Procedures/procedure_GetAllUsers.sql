USE IronVaultDB
GO


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

GRANT EXECUTE ON dbo.sp_GetAllUsers TO db_app_service;