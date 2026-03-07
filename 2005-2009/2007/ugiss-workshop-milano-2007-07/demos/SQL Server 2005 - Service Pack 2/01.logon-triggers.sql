------------------------------------------------------------------------
-- Script:		01.logon-triggers.sql
-- Author:		Gianluca Hotz (Solid Quality Learning)
-- Credits:		Luca Bianchi
-- Copyright:		Attribution-NonCommercial-ShareAlike 2.5
-- Version:		SQL Server 2005 Service Pack 2
-- Tab/indent size:	8
-- Description:		Script dimostrativo dei logon triggers
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Cambiamo contesto
------------------------------------------------------------------------
USE master;
GO

------------------------------------------------------------------------
-- Creiamo un login per effettuare il test
------------------------------------------------------------------------
IF EXISTS (
	SELECT	*
	FROM	sys.server_principals
	WHERE	name = 'TestLT'
	)
	DROP LOGIN TestLT
GO

CREATE LOGIN TestLT WITH PASSWORD = 'Test123';
GO

------------------------------------------------------------------------
-- Creiamo un trigger per tracciare l'operazione di logon e limitare
-- il numero di connessioni ad una per tutte le login tranne quelle
-- che afferiscono al ruolo sysadmin
------------------------------------------------------------------------
IF EXISTS (
	SELECT	*
	FROM	sys.server_triggers
	WHERE	name = 'tr_PermitSingleConnection'
	)
	DROP TRIGGER tr_PermitSingleConnection ON ALL SERVER
GO

CREATE TRIGGER tr_PermitSingleConnection
ON ALL SERVER
--WITH EXECUTE AS SELF
WITH EXECUTE AS 'sa'
FOR LOGON
AS
BEGIN
	IF	-- l'utente non e' un membro del ruolo sysadmin
		IS_SRVROLEMEMBER ('sysadmin', ORIGINAL_LOGIN()) = 0 
		-- ed ha piu' di una connessione aperta
	AND	(
		SELECT	COUNT(*) 
		FROM	sys.dm_exec_sessions
		WHERE	is_user_process = 1 
		  AND	original_login_name = ORIGINAL_LOGIN()
		) > 1
	BEGIN
		ROLLBACK;
	END
END;
GO

------------------------------------------------------------------------
-- Creiamo un trigger per permettere ai sysadmin di connettersi solo
-- da una determinata rete
------------------------------------------------------------------------
IF EXISTS (
	SELECT	*
	FROM	sys.server_triggers
	WHERE	name = 'tr_LimitSysadmin'
	)
	DROP TRIGGER tr_LimitSysadmin ON ALL SERVER
GO

CREATE TRIGGER tr_LimitSysAdmin
ON ALL SERVER
--WITH EXECUTE AS SELF
WITH EXECUTE AS 'sa'
FOR LOGON
AS
BEGIN
	IF	-- l'utente e' un membro del ruolo sysadmin
		IS_SRVROLEMEMBER ('sysadmin', ORIGINAL_LOGIN()) = 1
		-- ed ha piu' di una connessione aperta
	AND	NOT EXISTS (
		SELECT	*
		FROM	sys.dm_exec_connections
		WHERE	session_id = @@spid
		  AND	(client_net_address = '<local machine>'
			OR client_net_address LIKE '172.16.12.%')
			)
	BEGIN
		ROLLBACK;
	END
END;
GO


------------------------------------------------------------------------
-- Creiamo un trigger per tracciare gli accessi
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Creiamo un database per tracciare le logon
------------------------------------------------------------------------
IF EXISTS(SELECT * FROM sysdatabases WHERE name = 'TestLogonTG')
	DROP DATABASE TestLogonTG
GO

CREATE DATABASE TestLogonTG
GO

USE TestLogonTG
GO

------------------------------------------------------------------------
-- Creiamo una tabella per tracciare le logon
------------------------------------------------------------------------
IF OBJECT_ID('dbo.AuditLogon') IS NOT NULL
    DROP TABLE dbo.AuditLogon
GO

CREATE TABLE dbo.AuditLogon(
	AuditId		int IDENTITY(1, 1) NOT NULL
,	Data		datetime	NOT NULL
,	Spid		smallint	NOT NULL
,	Account		nvarchar(128)	NOT NULL
,	Host		nvarchar(15)	NOT NULL
,	IPAddress	varchar(48)	NOT NULL
,	Protocollo	varchar(40)	NOT NULL
,	AppName		nvarchar(128)	NOT NULL
,	CONSTRAINT	pkAuditLogon
	PRIMARY KEY	(AuditId)
)
GO

------------------------------------------------------------------------
-- Creiamo una trigger per tracciare le logon
------------------------------------------------------------------------
USE master 
GO

IF EXISTS (
	SELECT	*
	FROM	sys.server_triggers
	WHERE	name = 'tr_AuditLogon'
	)
	DROP TRIGGER tr_AuditLogon ON ALL SERVER
GO

CREATE TRIGGER tr_AuditLogon 
ON ALL SERVER
--WITH EXECUTE AS SELF
WITH EXECUTE AS 'sa'
FOR LOGON 
AS 
BEGIN 
	INSERT	TestLogonTG.dbo.AuditLogon (
		Data
	,	Spid
	,	Account
	,	Host
	,	IPAddress
	,	Protocollo
	,	AppName
	)
	SELECT	GETDATE(), @@SPID, ORIGINAL_LOGIN(), HOST_NAME(),
		client_net_address, net_transport, APP_NAME()
	FROM	sys.dm_exec_connections
	WHERE	session_id = @@spid
END;

------------------------------------------------------------------------
-- verifichiamo il contenuto
------------------------------------------------------------------------
SELECT * FROM TestLogonTG.dbo.AuditLogon
GO

------------------------------------------------------------------------
-- pulizia
------------------------------------------------------------------------
IF EXISTS (
	SELECT	*
	FROM	sys.server_triggers
	WHERE	name = 'tr_PermitSingleConnection'
	)
	DROP TRIGGER tr_PermitSingleConnection ON ALL SERVER
GO
IF EXISTS (
	SELECT	*
	FROM	sys.server_triggers
	WHERE	name = 'tr_LimitSysadmin'
	)
	DROP TRIGGER tr_LimitSysadmin ON ALL SERVER
GO
IF EXISTS (
	SELECT	*
	FROM	sys.server_triggers
	WHERE	name = 'tr_AuditLogon'
	)
	DROP TRIGGER tr_AuditLogon ON ALL SERVER
GO
