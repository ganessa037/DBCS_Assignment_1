Use IronVaultDB
GO

CREATE PROCEDURE dbo.sp_GetUserByEmail
    @Email VARCHAR(320)
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

CREATE OR ALTER PROCEDURE dbo.sp_GetUserById
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        u.UserID,
        u.User_Name,
        r.Role_Name,
        r.RoleID
    FROM [User] u
    LEFT JOIN [Role] r ON u.RoleID = r.RoleID
    WHERE u.UserID = @UserID;
END;
GO

-- to execute
EXEC dbo.sp_GetUserByEmail 'natasha@gmail.com'
EXEC dbo.sp_GetUserById 1
