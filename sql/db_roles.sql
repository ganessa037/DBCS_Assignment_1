-- db account creation and access
CREATE LOGIN ironvault_dba_login WITH PASSWORD = 'Pa$$w0rd'; -- manage schema, users, auditing
CREATE LOGIN ironvault_auditor_login WITH PASSWORD = 'Pa$$w0rd'; -- have access to audits, read-only
CREATE LOGIN ironvault_app_login WITH PASSWORD = 'Pa$$w0rd'; -- for app service, the manager, admin and customer only have this
CREATE LOGIN ironvault_dev_login WITH PASSWORD = 'Pa$$w0rd'; -- for dev

-- create database users for ironvaultDB
USE IronVaultDB;
GO

CREATE USER ironvault_dba_user FOR LOGIN ironvault_dba_login;
CREATE USER ironvault_auditor_user FOR LOGIN ironvault_auditor_login;
CREATE USER ironvault_app_user FOR LOGIN ironvault_app_login; -- establish connection with application using this account
CREATE USER ironvault_dev_user FOR LOGIN ironvault_dev_login;

-- create database roles
CREATE ROLE db_dba;
CREATE ROLE db_app_service;
CREATE ROLE db_auditor;
CREATE ROLE db_developer;

-- assign users to these roles
ALTER ROLE db_dba ADD MEMBER ironvault_dba_user;
ALTER ROLE db_app_service ADD MEMBER ironvault_app_user;
ALTER ROLE db_auditor ADD MEMBER ironvault_auditor_user;
ALTER ROLE db_developer ADD MEMBER ironvault_dev_user;

-- grant permissions
GRANT CONTROL ON DATABASE::IronVaultDB TO db_dba; -- full schema, table, audit management

-- least privilege
GRANT SELECT, INSERT, UPDATE ON dbo.[User] TO db_app_service;
GRANT SELECT, INSERT, UPDATE ON dbo.Account TO db_app_service;
GRANT SELECT, INSERT ON dbo.[Transaction] TO db_app_service;
GRANT SELECT, INSERT ON dbo.Application_Audit_Log TO db_app_service;
GRANT SELECT ON dbo.[Role] TO db_app_service;
GRANT EXECUTE ON dbo.sp_GetAccountsByUser TO db_app_service; -- must have the procedures first
GRANT EXECUTE ON dbo.sp_CreateAccount TO db_app_service; -- must have procedures first
GRANT EXECUTE ON dbo.sp_GetUserEmail TO db_app_service; -- must have procedures
GRANT EXECUTE ON dbo.sp_GetUserById TO db_app_service; -- must have procedures
GRANT SELECT ON dbo.fn_security_predicate_user_account TO db_app_service;
GRANT SELECT ON dbo.fn_security_predicate_user_transaction TO db_app_service;
GRANT SELECT ON dbo.fn_security_predicate_user TO db_app_service;
GRANT SELECT ON dbo.fn_security_predicate_audit_log TO db_app_service;
GRANT EXECUTE ON dbo.sp_GetUserByEmail TO db_app_service;
GRANT EXECUTE ON dbo.sp_UpdateUserRoleAndStatus TO db_app_service;
GRANT EXECUTE ON dbo.sp_UserLogin TO db_app_service;
GRANT EXECUTE ON dbo.sp_TransferFunds TO db_app_service;
GRANT EXECUTE ON dbo.sp_Deposit TO db_app_service;
GRANT EXECUTE ON dbo.sp_GetTransactionsByUser TO db_app_service;
GRANT EXECUTE ON dbo.sp_GetAllCustomerAccounts TO db_app_service;
GRANT EXECUTE ON dbo.sp_GetAllUsers TO db_app_service;
GRANT EXECUTE ON dbo.sp_GetAuditLogs TO db_app_service;


GRANT SELECT ON dbo.[User] TO db_auditor;
GRANT SELECT ON dbo.Account TO db_auditor;
GRANT SELECT ON dbo.[Transaction] TO db_auditor;
DENY INSERT, UPDATE, DELETE ON SCHEMA::dbo TO db_auditor;

GRANT SELECT ON SCHEMA::dbo TO db_developer;
DENY INSERT, UPDATE, DELETE ON SCHEMA::dbo TO db_developer;

