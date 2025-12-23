-- ====================================================
-- Step 5: Grant Permissions
-- Grant least privilege by default
-- ====================================================


-- database admin: full control on the database
-- grant full schema, table, audit management
-- this is not the same as database owner
GRANT CONTROL ON DATABASE::IronVaultDB TO db_dba;
GRANT UNMASK TO db_dba;

-- auth service: to bypass RLS when checking if 
-- if user exists during login
GRANT SELECT ON dbo.[User] TO auth_service;

-- transaction service: anything related to the account
-- used to execute procedures since db_app_service is with least privelege
GRANT SELECT, UPDATE ON dbo.Account TO transaction_service;
GRANT SELECT, INSERT ON dbo.[Transaction] TO transaction_service;
GRANT SELECT ON dbo.[User] TO transaction_service;
GRANT SELECT ON dbo.Role TO transaction_service;
GRANT INSERT ON dbo.Application_Audit_Log TO transaction_service;
GRANT VIEW DEFINITION ON SYMMETRIC KEY::IronVaultSymKey TO transaction_service;
GRANT CONTROL ON CERTIFICATE::IronVaultCert TO transaction_service;
GRANT UNMASK TO transaction_service;

-- auditor: database user that can see the audits
-- strictly read-only, no need access to the app audit
GRANT SELECT ON dbo.[User] TO db_auditor;
GRANT SELECT ON dbo.Account TO db_auditor;
GRANT SELECT ON dbo.[Transaction] TO db_auditor;
DENY INSERT, UPDATE, DELETE ON SCHEMA::dbo TO db_auditor;
GRANT UNMASK ON OBJECT::dbo.Account(Acc_Balance) TO db_auditor;
GRANT UNMASK ON OBJECT::dbo.[Transaction](Amount) TO db_auditor;

-- developer: for development, read-only
-- but cannot change anything
GRANT SELECT ON SCHEMA::dbo TO db_developer;
DENY INSERT, UPDATE, DELETE ON SCHEMA::dbo TO db_developer;
GRANT UNMASK TO db_developer;



-- least privilege
GRANT SELECT, INSERT, UPDATE ON dbo.[User] TO db_app_service;
GRANT SELECT, INSERT, UPDATE ON dbo.Account TO db_app_service;
GRANT SELECT, INSERT ON dbo.[Transaction] TO db_app_service;
GRANT SELECT, INSERT ON dbo.Application_Audit_Log TO db_app_service;
GRANT SELECT ON dbo.[Role] TO db_app_service;

