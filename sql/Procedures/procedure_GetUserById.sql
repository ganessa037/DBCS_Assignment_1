USE IronVaultDB
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
GRANT EXECUTE ON dbo.sp_GetUserById TO db_app_service;