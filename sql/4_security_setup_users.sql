-- ====================================================
-- Step 4: Create Database Roles, Users and Services
-- Database roles are not the same as application roles
-- ====================================================


-- create database roles
CREATE ROLE db_dba; 
CREATE ROLE db_app_service; -- connect to flask using this
CREATE ROLE db_auditor;
CREATE ROLE db_developer;
CREATE ROLE db_service_account; -- exists, but without login

-- db account creation and access
CREATE LOGIN ironvault_dba_login WITH PASSWORD = 'Pa$$w0rd'; -- manage schema, users, auditing
CREATE LOGIN ironvault_auditor_login WITH PASSWORD = 'Pa$$w0rd'; -- have access to audits, read-only
CREATE LOGIN ironvault_app_login WITH PASSWORD = 'Pa$$w0rd'; -- for app service, the manager, admin and customer only have this
CREATE LOGIN ironvault_dev_login WITH PASSWORD = 'Pa$$w0rd'; -- for dev

-- create database users for ironvaultDB
USE IronVaultDB;
GO

-- users with login
CREATE USER ironvault_dba_user FOR LOGIN ironvault_dba_login;
CREATE USER ironvault_auditor_user FOR LOGIN ironvault_auditor_login;
CREATE USER ironvault_app_user FOR LOGIN ironvault_app_login;
CREATE USER ironvault_dev_user FOR LOGIN ironvault_dev_login;

-- services, no login
CREATE USER auth_service WITHOUT LOGIN;
CREATE USER transaction_service WITHOUT LOGIN;


-- assign users based on roles

-- database accounts
ALTER ROLE db_dba ADD MEMBER ironvault_dba_user;
ALTER ROLE db_app_service ADD MEMBER ironvault_app_user;
ALTER ROLE db_auditor ADD MEMBER ironvault_auditor_user;
ALTER ROLE db_developer ADD MEMBER ironvault_dev_user;

-- database services
ALTER ROLE db_service_account ADD MEMBER auth_service;
ALTER ROLE db_service_account ADD MEMBER transaction_service;

