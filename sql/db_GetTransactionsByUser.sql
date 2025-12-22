Use IronVaultDB
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetTransactionsByUser
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        t.TransactionID,
        t.Transaction_Date,
        t.Transaction_Type,
        t.Amount,
        t.Description,
        t.SenderAccountID,
        t.ReceiverAccountID,
        CONVERT(VARCHAR(20), s.DecryptAcc) AS SenderAccount,
        CONVERT(VARCHAR(20), r.DecryptAcc) AS ReceiverAccount,
        CASE 
            WHEN t.SenderAccountID IN (SELECT AccountID FROM Account WHERE UserID = @UserID) THEN 'Debit'
            ELSE 'Credit'
        END AS Transaction_Direction
    FROM [Transaction] t
    LEFT JOIN (
        SELECT AccountID, DecryptByKey(Acc_Number_Encrypted) AS DecryptAcc
        FROM Account
    ) s ON t.SenderAccountID = s.AccountID
    LEFT JOIN (
        SELECT AccountID, DecryptByKey(Acc_Number_Encrypted) AS DecryptAcc
        FROM Account
    ) r ON t.ReceiverAccountID = r.AccountID
    WHERE t.SenderAccountID IN (SELECT AccountID FROM Account WHERE UserID = @UserID)
       OR t.ReceiverAccountID IN (SELECT AccountID FROM Account WHERE UserID = @UserID)
    ORDER BY t.Transaction_Date DESC;
END;

CREATE OR ALTER PROCEDURE dbo.sp_GetAllCustomerAccounts
AS
BEGIN
    SET NOCOUNT ON;

    SELECT u.UserID, u.User_Name, CONVERT(VARCHAR(20), DecryptByKey(a.Acc_Number_Encrypted)) AS Acc_Number, a.Acc_Balance
    FROM Account a
    JOIN [User] u ON a.UserID = u.UserID
    JOIN [Role] r ON u.RoleID = r.RoleID
    WHERE r.Role_Name = 'Customer';
END;

CREATE OR ALTER PROCEDURE dbo.sp_GetAllUsers
AS
BEGIN
    SET NOCOUNT ON;

    SELECT u.UserID, u.User_Name, u.User_Email_Hash AS User_Email, r.Role_Name, u.RoleID,
           ISNULL(u.Status, 'Active') AS Status
    FROM [User] u
    JOIN [Role] r ON u.RoleID = r.RoleID;
END;

CREATE OR ALTER PROCEDURE dbo.sp_GetAuditLogs
    @Top INT = 50
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@Top) *
    FROM Application_Audit_Log
    ORDER BY Action_Date DESC;
END;