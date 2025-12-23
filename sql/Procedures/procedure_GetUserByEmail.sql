Use IronVaultDB
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetUserByEmail
    @Email VARCHAR(320)
WITH EXECUTE AS 'auth_service'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EmailHash VARBINARY(32) = HASHBYTES('SHA2_256', LOWER(@Email));

    SELECT 
        UserID,
        User_Name,
        User_PasswordHash,
        User_Salt,
        RoleID
    FROM [User]
    WHERE User_Email_Hash = @EmailHash;
END;
GO

-- grant permission
GRANT EXECUTE ON dbo.sp_GetUserByEmail TO db_app_service;

-- to execute
EXEC dbo.sp_GetUserByEmail 'natasha@gmail.com'