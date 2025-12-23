USE IronVaultDB
GO

CREATE PROCEDURE dbo.sp_GetUserEmail
    @UserID INT
AS
BEGIN
    OPEN SYMMETRIC KEY IronVaultSymKey
    DECRYPTION BY CERTIFICATE IronVaultCert;

    SELECT
        CONVERT(VARCHAR(255), DecryptByKey(User_Email_Encrypted)) AS User_Email
    FROM [User]
    WHERE UserID = @UserID;

    CLOSE SYMMETRIC KEY IronVaultSymKey;
END;

GRANT EXECUTE ON dbo.sp_GetUserEmail TO db_app_service;

-- to exec
EXEC dbo.sp_GetUserEmail 1;