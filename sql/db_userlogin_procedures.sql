Use IronVaultDB;
GO

-- login procedure
CREATE OR ALTER PROCEDURE sp_UserLogin
    @UserID INT,
    @IP_Address VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UserName VARCHAR(255);
    DECLARE @RoleName VARCHAR(100);

    -- Get the user name and role name
    SELECT 
        @UserName = u.User_Name,
        @RoleName = r.Role_Name
    FROM [User] u
    LEFT JOIN [Role] r ON u.RoleID = r.RoleID
    WHERE u.UserID = @UserID;

    -- Update Last_Login if column exists
    IF COL_LENGTH('dbo.[User]', 'Last_Login') IS NOT NULL
    BEGIN
        UPDATE [User]
        SET Last_Login = GETDATE()
        WHERE UserID = @UserID;
    END

    -- Insert audit log
    INSERT INTO Application_Audit_Log
        (UserID, User_Name, Role_Name, Action_Type, Status, Message, IP_Address)
    VALUES
        (@UserID, @UserName, @RoleName, 'LOGIN', 'Success', 'User logged in successfully', @IP_Address);
END

-- to execute
EXEC sp_UserLogin 1, '169.7.205.27';