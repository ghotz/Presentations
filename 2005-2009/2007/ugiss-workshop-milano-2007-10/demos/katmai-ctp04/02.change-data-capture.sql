------------------------------------------------------------------------
-- Script:			02.change-data-capture.sql
-- Author:			Gianluca Hotz (Solid Quality Learning)
-- Copyright:		Attribution-NonCommercial-ShareAlike 2.5
-- Version:			SQL Server 2008 CTP3
-- Tab/indent size:	4
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Cambiamo contesto.
------------------------------------------------------------------------
USE master
GO

------------------------------------------------------------------------
-- Creiamo il database di test.
------------------------------------------------------------------------
IF EXISTS(SELECT * FROM sysdatabases WHERE name = 'TestCDC')
	DROP DATABASE TestCDC
GO

CREATE DATABASE TestCDC
ON PRIMARY (
	NAME		= 'TestCDC_mdf'
,	FILENAME	= 'C:\Program Files\Microsoft SQL Server\MSSQL.1\MSSQL\Data\TestCDC.mdf'
,	SIZE		= 10MB
,	MAXSIZE		= 50MB
,	FILEGROWTH	= 10MB
)
LOG ON (
	NAME		= 'TestCDC_log'
,	FILENAME	= 'C:\Program Files\Microsoft SQL Server\MSSQL.1\MSSQL\Data\TestCDC.ldf'
,	SIZE		= 10MB
,	MAXSIZE		= 500MB
,	FILEGROWTH	= 100MB
)
GO

------------------------------------------------------------------------
-- Aggiungiamo un filegroup per la tabella che conterra' la tabella
------------------------------------------------------------------------
ALTER DATABASE	TestCDC
ADD FILEGROUP	EMPBASE
GO

------------------------------------------------------------------------
-- Aggiungiamo un file al filegroup
------------------------------------------------------------------------
ALTER DATABASE	TestCDC
ADD FILE (
	NAME		= 'TestCDC_empbase'
,	FILENAME	= 'C:\Program Files\Microsoft SQL Server\MSSQL.1\MSSQL\Data\TestCDC_empbase.ndf'
,	SIZE		= 10MB
,	MAXSIZE		= 100MB
,	FILEGROWTH	= 10MB
)
TO FILEGROUP EMPBASE
GO

------------------------------------------------------------------------
-- Aggiungiamo un filegroup per la tabella che conterra' le modifiche
------------------------------------------------------------------------
ALTER DATABASE	TestCDC
ADD FILEGROUP	EMPHISTORY
GO

------------------------------------------------------------------------
-- Aggiungiamo un file al filegroup
------------------------------------------------------------------------
ALTER DATABASE	TestCDC
ADD FILE (
	NAME		= 'TestCDC_emphistory'
,	FILENAME	= 'C:\Program Files\Microsoft SQL Server\MSSQL.1\MSSQL\Data\TestCDC_emphistory.ndf'
,	SIZE		= 10MB
,	MAXSIZE		= 100MB
,	FILEGROWTH	= 10MB
)
TO FILEGROUP EMPHISTORY
GO

------------------------------------------------------------------------
-- Cambiamo contesto
------------------------------------------------------------------------
USE TestCDC
GO

------------------------------------------------------------------------
-- Creiamo la tabella degli impiegati
------------------------------------------------------------------------
CREATE TABLE dbo.Employees (
	EmployeeID	int				NOT NULL
,	LastName	nvarchar(20)	NOT NULL
,	FirstName	nvarchar(10)	NOT NULL

,	CONSTRAINT	PK_Employees_base
	PRIMARY KEY	(EmployeeID)
	ON			EMPBASE
) ON EMPBASE
GO

------------------------------------------------------------------------
-- Impostiamo il recovery model a simple
------------------------------------------------------------------------
ALTER DATABASE TestCDC SET RECOVERY SIMPLE
GO

------------------------------------------------------------------------
-- Inseriamo almeno un impiegato
------------------------------------------------------------------------
INSERT dbo.Employees VALUES(1,'Davolio','Nancy')
GO

------------------------------------------------------------------------
-- Abilitiamo il data capture a livello di database
------------------------------------------------------------------------
EXEC	sys.sp_cdc_enable_db_change_data_capture
GO

------------------------------------------------------------------------
-- Possiamo verificare immediatamente le modifiche allo schema
------------------------------------------------------------------------
SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'cdc'
SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_SCHEMA = 'cdc'
GO

------------------------------------------------------------------------
-- Abilitiamo il data capture per la tabella catturata
------------------------------------------------------------------------
EXEC	sys.sp_cdc_enable_table_change_data_capture 
		@source_schema = 'dbo'
,		@source_name = 'Employees'
,		@role_name = 'public'
,		@capture_instance = NULL		-- nome derivato direttamente
,		@supports_net_changes = 1
,		@index_name = NULL				-- utilizza la chiave primaria
,		@captured_column_list = NULL	-- tutte le colonne
,		@filegroup_name = 'EMPHISTORY'
GO

------------------------------------------------------------------------
-- Verifichiamo le modifiche alllo schema
------------------------------------------------------------------------
SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'cdc'
SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_SCHEMA = 'cdc'
GO

------------------------------------------------------------------------
-- Inseriamo altri due impiegati
------------------------------------------------------------------------
INSERT dbo.Employees VALUES(2,'Fuller','Andrew')
INSERT dbo.Employees VALUES(3,'Leverling','Janet')
GO

------------------------------------------------------------------------
-- Vediamo le modifiche
------------------------------------------------------------------------
DECLARE	@begin_time datetime
DECLARE	@end_time	datetime
DECLARE	@from_lsn	binary(10)
DECLARE	@to_lsn		binary(10)

SET		@begin_time = GETDATE()-1
SET		@end_time = GETDATE()

-- mappiamo l'intervallo temporale in un intervallo di LSN
SELECT	@from_lsn =	sys.fn_cdc_map_time_to_lsn(
						'smallest greater than or equal'
					,	@begin_time)
SELECT	@to_lsn =	sys.fn_cdc_map_time_to_lsn(
						'largest less than or equal'
					,	@end_time)

-- selezioniamo le righe in quell'intervallo
SELECT	*
FROM	cdc.fn_cdc_get_all_changes_dbo_Employees(
			@from_lsn
		,	@to_lsn
		,	'all')
GO

------------------------------------------------------------------------
-- Facciamo altre modifiche
------------------------------------------------------------------------
UPDATE	dbo.Employees
SET		FirstName = 'Jeanet'
WHERE	EmployeeId = 3
GO

DELETE	dbo.Employees
WHERE	EmployeeId = 3
GO

------------------------------------------------------------------------
-- Vediamo le modifiche
------------------------------------------------------------------------
DECLARE	@begin_time datetime
DECLARE	@end_time	datetime
DECLARE	@from_lsn	binary(10)
DECLARE	@to_lsn		binary(10)

SET		@begin_time = GETDATE()-1
SET		@end_time = GETDATE()

-- mappiamo l'intervallo temporale in un intervallo di LSN
SELECT	@from_lsn =	sys.fn_cdc_map_time_to_lsn(
						'smallest greater than or equal'
					,	@begin_time)
SELECT	@to_lsn =	sys.fn_cdc_map_time_to_lsn(
						'largest less than or equal'
					,	@end_time)

-- selezioniamo le righe in quell'intervallo
SELECT	*
FROM	cdc.fn_cdc_get_all_changes_dbo_Employees(
			@from_lsn
		,	@to_lsn
		,	'all')
GO

------------------------------------------------------------------------
-- Tabelle di sistema
------------------------------------------------------------------------
SELECT * FROM cdc.change_tables
SELECT * FROM cdc.lsn_time_mapping
SELECT * FROM cdc.dbo_Employees_CT
GO

------------------------------------------------------------------------
-- Eliminiamo la tabella
------------------------------------------------------------------------
DROP TABLE dbo.Employees
GO

------------------------------------------------------------------------
-- Le modifiche allo schema per la tabella sono state eliminate
-- ma non quelle generiche per il Change Data Capture e i job
------------------------------------------------------------------------
SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'cdc'
SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_SCHEMA = 'cdc'
GO

------------------------------------------------------------------------
-- Eliminiamo il supporto a CDC
------------------------------------------------------------------------
EXEC	sys.sp_cdc_disable_db_change_data_capture
GO
