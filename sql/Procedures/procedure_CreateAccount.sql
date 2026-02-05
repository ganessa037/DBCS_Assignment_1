USE IronVaultDB;
GO

-- insert and update 
ALTER PROCEDURE dbo.sp_CreateAccount
    @UserName VARCHAR(255),
    @Email VARCHAR(320),
    @PasswordHash VARCHAR(500),
    @Salt VARCHAR(100),
    @RoleID INT = 2
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Hash the email for duplicate checking
        DECLARE @EmailHash VARBINARY(32) = HASHBYTES('SHA2_256', LOWER(@Email));
        
        -- Check duplicate email using HASH
        IF EXISTS (SELECT 1 FROM [User] WHERE User_Email_Hash = @EmailHash)
        BEGIN
            RAISERROR('Email already registered.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Open symmetric key for encryption
        OPEN SYMMETRIC KEY IronVaultSymKey
        DECRYPTION BY PASSWORD = 'Pa$$w0rd';
        
        -- Encrypt the email
        DECLARE @EncryptedEmail VARBINARY(MAX) = EncryptByKey(
            Key_GUID('IronVaultSymKey'), 
            @Email
        );
        
        -- Insert new user with BOTH encrypted email AND hash
        INSERT INTO [User] 
            (User_Name, User_Email_Encrypted, User_Email_Hash, User_PasswordHash, User_Salt, RoleID)
        VALUES 
            (@UserName, @EncryptedEmail, @EmailHash, @PasswordHash, @Salt, @RoleID);
        
        DECLARE @NewUserID INT = SCOPE_IDENTITY();
        
        -- Create account
        INSERT INTO Account (
            UserID,
            Acc_Number_Encrypted,
            Acc_Balance
        )
        VALUES (
            @NewUserID,
            EncryptByKey(
                Key_GUID('IronVaultSymKey'),
                '100-' + CAST(@NewUserID AS VARCHAR)
            ),
            0.00
        );
        
        CLOSE SYMMETRIC KEY IronVaultSymKey;
        
        COMMIT TRANSACTION;
        
        SELECT @NewUserID AS UserID;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        IF (SELECT COUNT(*) FROM sys.openkeys WHERE key_name = 'IronVaultSymKey') > 0
            CLOSE SYMMETRIC KEY IronVaultSymKey;
            
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;
GO

-- grant to flask
GRANT EXECUTE ON dbo.sp_CreateAccount TO db_app_service;

-- to execute
EXEC dbo.sp_CreateAccount
    @UserName = 'Jane Doe',
    @Email = 'jeannie@example.com',
    @PasswordHash = 'hashed_password_here',
    @Salt = 'random_salt_here',
    @RoleID = 2;