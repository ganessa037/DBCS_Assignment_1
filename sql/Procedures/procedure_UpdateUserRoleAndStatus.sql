Use IronVaultDB
GO

CREATE OR ALTER PROCEDURE dbo.sp_UpdateUserRoleAndStatus
    @TargetUserID INT,
    @NewRoleID INT,
    @NewStatus VARCHAR(100) = 'Active',
    @ActorUserID INT,
    @ActorUserName NVARCHAR(255),
    @ActorRoleName NVARCHAR(100),
    @ActorIP NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OldRoleID INT;
    DECLARE @Changes NVARCHAR(MAX) = '';

    -- Get old role
    SELECT @OldRoleID = RoleID FROM [User] WHERE UserID = @TargetUserID;

    IF @OldRoleID IS NULL
    BEGIN
        RAISERROR('Target user not found.', 16, 1);
        RETURN;
    END

    -- Update Role if changed
    IF @OldRoleID <> @NewRoleID
    BEGIN
        UPDATE [User] SET RoleID = @NewRoleID WHERE UserID = @TargetUserID;
        DECLARE @OldRoleName NVARCHAR(100) = (SELECT Role_Name FROM [Role] WHERE RoleID = @OldRoleID);
        DECLARE @NewRoleName NVARCHAR(100) = (SELECT Role_Name FROM [Role] WHERE RoleID = @NewRoleID);
        SET @Changes = CONCAT(@Changes, 'Role: ', @OldRoleName, ' → ', @NewRoleName, '; ');
    END

    -- Update Status if column exists
    BEGIN TRY
        UPDATE [User] SET Status = @NewStatus WHERE UserID = @TargetUserID;
        SET @Changes = CONCAT(@Changes, 'Status: ', @NewStatus, '; ');
    END TRY
    BEGIN CATCH
        -- Skip if column doesn't exist
    END CATCH

    -- Log the change
    IF LEN(@Changes) > 0
    BEGIN
        INSERT INTO Application_Audit_Log (UserID, User_Name, Role_Name, Action_Type, Status, Message, IP_Address)
        VALUES (@ActorUserID, @ActorUserName, @ActorRoleName, 'USER_UPDATE', 'Success',
                CONCAT('Updated User ', @TargetUserID, ': ', @Changes), @ActorIP);
    END
END
GO
GRANT EXECUTE ON dbo.sp_UpdateUserRoleAndStatus TO db_app_service;