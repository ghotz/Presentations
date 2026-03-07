------------------------------------------------------------------------
-- Script:		sql2017-db-development.sql
-- Copyright:	2017 Gianluca Hotz
-- License:		MIT License
-- Credits:
------------------------------------------------------------------------

------------------------------------------------------------------------
-- SELECT...INTO ... ON filegroup
------------------------------------------------------------------------

-- create database with secondary filegroup adnd set primary as default
USE master;
GO
IF EXISTS (SELECT * FROM sys.databases WHERE [name] = 'TestDB') DROP DATABASE TestDB;
GO
CREATE DATABASE TestDB
ON PRIMARY 
	( NAME = N'TestDB', FILENAME = N'C:\SQLServer\MSSQL14.SQL2017\MSSQL\DATA\TestDB.mdf'), 
FILEGROUP [SECONDARY] 
	( NAME = N'TestDB_SECONDARY', FILENAME = N'C:\SQLServer\MSSQL14.SQL2017\MSSQL\DATA\TestDB_SECONDARY.ndf')
LOG ON 
	( NAME = N'TestDB_log', FILENAME = N'C:\SQLServer\MSSQL14.SQL2017\MSSQL\DATA\TestDB_log.ldf')
GO
USE TestDB
GO
IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N'PRIMARY') ALTER DATABASE [TestDB] MODIFY FILEGROUP [PRIMARY] DEFAULT;
GO

-- new select/into example
SELECT	*
INTO	dbo.Product
ON		[SECONDARY]
FROM	AdventureWorks2017.Production.Product
GO

------------------------------------------------------------------------
-- BULK INSERT/OPENROWSET CSV support
------------------------------------------------------------------------
-- notepad "C:\Users\Gianluca\OneDrive\Documents\Presentations\UGISS\20171128 WPC 2017\Demos\services.csv"
DROP TABLE IF EXISTS dbo.ServiceStartup;
CREATE TABLE dbo.ServiceStartup (
	ServiceName	nvarchar(256) NOT NULL PRIMARY KEY
,	StartType	nvarchar(20) NOT NULL
);
GO

BULK INSERT dbo.ServiceStartup
FROM 'C:\Users\Gianluca\OneDrive\Documents\Presentations\UGISS\20171128 WPC 2017\Demos\services.csv'
WITH (FORMAT = 'CSV');
GO

SELECT * FROM dbo.ServiceStartup;
GO

SELECT	T1.*
FROM	OPENROWSET(
			BULK 'C:\Users\Gianluca\OneDrive\Documents\Presentations\UGISS\20171128 WPC 2017\Demos\services.csv'
		,	FORMATFILE = 'C:\Users\Gianluca\OneDrive\Documents\Presentations\UGISS\20171128 WPC 2017\Demos\services.fmt'
		,	FIRSTROW = 1
		,	FORMAT = 'CSV'
		) AS T1;
GO

------------------------------------------------------------------------
-- BULK INSERT/OPENROWSET BLOB_STORAGE support
------------------------------------------------------------------------
USE TestDB;
GO

CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Passw0rd!'; 
GO

IF EXISTS (SELECT * FROM sys.external_data_sources WHERE [name] = 'AzureContainer')
	DROP EXTERNAL DATA SOURCE AzureContainer;
IF EXISTS(SELECT * FROM sys.database_scoped_credentials WHERE [name] = 'AzureCredential')
	DROP DATABASE SCOPED CREDENTIAL AzureCredential;
GO

CREATE DATABASE SCOPED CREDENTIAL AzureCredential
WITH
	--	this is the name of the storage account
	IDENTITY= 'SHARED ACCESS SIGNATURE'
	--	this needs to be a SAS without the initial ? character
,	SECRET = 'sv=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
GO

CREATE EXTERNAL DATA SOURCE AzureContainer
WITH (   
    TYPE = BLOB_STORAGE
    ,	LOCATION = 'https://azurebackdemo.blob.core.windows.net/csv'
    ,	CREDENTIAL = AzureCredential
) ;
GO

DROP TABLE IF EXISTS dbo.ServiceStartup;
CREATE TABLE dbo.ServiceStartup (
	ServiceName	nvarchar(256) NOT NULL PRIMARY KEY
,	StartType	nvarchar(20) NOT NULL
);
GO

BULK INSERT dbo.ServiceStartup
FROM 'services.csv'
WITH (DATA_SOURCE = 'AzureContainer', FORMAT = 'CSV');
GO

SELECT * FROM dbo.ServiceStartup;
GO
