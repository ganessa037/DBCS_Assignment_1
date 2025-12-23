USE IronVaultDB;
GO

-- delete users
CREATE OR ALTER PROCEDURE dbo.sp_DeleteUser
    @UserID INT,
    @ActorUserID INT,      -- user performing the deletion
    @ActorUserName NVARCHAR(255),
    @ActorRoleName NVARCHAR(100),
    @ActorIP NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    -- Delete related transactions
    DELETE FROM [Transaction]
    WHERE SenderAccountID IN (SELECT AccountID FROM Account WHERE UserID = @UserID)
       OR ReceiverAccountID IN (SELECT AccountID FROM Account WHERE UserID = @UserID);

    -- Delete audit logs for the target user
    DELETE FROM Application_Audit_Log WHERE UserID = @UserID;

    -- Delete accounts
    DELETE FROM Account WHERE UserID = @UserID;

    -- Delete the user
    DELETE FROM [User] WHERE UserID = @UserID;

    -- Log deletion by actor
    INSERT INTO Application_Audit_Log (UserID, User_Name, Role_Name, Action_Type, Status, Message, IP_Address)
    VALUES (@ActorUserID, @ActorUserName, @ActorRoleName, 'DELETE_USER', 'Success', CONCAT('Deleted User ID ', @UserID), @ActorIP);
END
GO