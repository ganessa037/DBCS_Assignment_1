-- introduce an account view, so flask can take from here
USE IronVaultDB;
GO

CREATE VIEW vw_Account AS
SELECT AccountID, UserID,
       CONVERT(varchar(20), DecryptByKey(Acc_Number_Encrypted)) AS Acc_Number,
       Acc_Balance
FROM Account;