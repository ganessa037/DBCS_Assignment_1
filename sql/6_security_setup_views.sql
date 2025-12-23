-- ====================================================
-- Step 6: Using views to access account
-- Avoid from direct
-- ====================================================

USE IronVaultDB;
GO

CREATE OR ALTER VIEW vw_Account AS
SELECT AccountID, UserID,
       CONVERT(varchar(20), DecryptByKey(Acc_Number_Encrypted)) AS Acc_Number,
       Acc_Balance
FROM Account;

-- grant service to execute this view
GRANT SELECT ON dbo.vw_Account TO transaction_service;