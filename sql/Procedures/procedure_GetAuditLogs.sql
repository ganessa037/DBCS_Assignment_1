USE IronVaultDB
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetAuditLogs
    @Top INT = 50
WITH EXECUTE AS 'transaction_service'  -- This user has UNMASK permission
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@Top) 
        LogID,
        UserID,
        User_Name,
        Role_Name,
        Action_Type,
        Status,
        Message,
        Action_Date,
        -- Mask last octet: 192.168.1.100 becomes 192.168.1.xxx
        CASE 
            WHEN IP_Address IS NOT NULL AND IP_Address LIKE '%.%.%.%' THEN
                SUBSTRING(IP_Address, 1, LEN(IP_Address) - CHARINDEX('.', REVERSE(IP_Address))) + '.xxx'
            ELSE 
                IP_Address
        END AS IP_Address
    FROM Application_Audit_Log
    ORDER BY Action_Date DESC;
END;
GO
GRANT EXECUTE ON dbo.sp_GetAuditLogs TO db_app_service;