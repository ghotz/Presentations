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
	( NAME = N'TestDB', FILENAME = N'C:\SQLServer\MSSQL14.MSSQLSERVER\MSSQL\DATA\TestDB.mdf'), 
FILEGROUP [SECONDARY] 
	( NAME = N'TestDB_SECONDARY', FILENAME = N'C:\SQLServer\MSSQL14.MSSQLSERVER\MSSQL\DATA\TestDB_SECONDARY.ndf')
LOG ON 
	( NAME = N'TestDB_log', FILENAME = N'C:\SQLServer\MSSQL14.MSSQLSERVER\MSSQL\DATA\TestDB_log.ldf')
GO
USE TestDB
GO
IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N'PRIMARY') ALTER DATABASE [TestDB] MODIFY FILEGROUP [PRIMARY] DEFAULT;
GO

-- new select/into example
-- (warning up to SSMS 17.5 if you have "enable parametrization for Always Encrypted on" and "Column Encryption Setting=Enabled" it throws an error!)
SELECT	*
INTO	[dbo].[Product]
ON		[SECONDARY]
FROM	AdventureWorks2017.Production.Product;
GO

------------------------------------------------------------------------
-- BULK INSERT/OPENROWSET CSV support
------------------------------------------------------------------------
-- check how the database is formatted first
-- notepad "C:\Users\gianl\OneDrive\Documents\Presentations\UGISS\20180912 Italian Virtual Chapter\Demos\services.csv"

-- Create destination table, dropping it if already existing
DROP TABLE IF EXISTS dbo.ServiceStartup;
CREATE TABLE dbo.ServiceStartup (
	ServiceName	nvarchar(256) NOT NULL PRIMARY KEY
,	StartType	nvarchar(20) NOT NULL
);
GO

-- Import CSV formatted data
BULK INSERT dbo.ServiceStartup
FROM 'C:\Users\gianl\OneDrive\Documents\Presentations\UGISS\20180912 Italian Virtual Chapter\Demos\services.csv'
WITH (FORMAT = 'CSV');
GO

-- Verify that data has been imported
SELECT * FROM dbo.ServiceStartup;
GO

-- CSV formatted files can be opened directly using OPENROWSET
-- although we still need a format file to specify column metadata (name, type)
-- notepad "C:\Users\gianl\OneDrive\Documents\Presentations\UGISS\20180912 Italian Virtual Chapter\Demos\services.fmt"
SELECT	T1.*
FROM	OPENROWSET(
			BULK 'C:\Users\gianl\OneDrive\Documents\Presentations\UGISS\20180912 Italian Virtual Chapter\Demos\services.csv'
		,	FORMATFILE = 'C:\Users\gianl\OneDrive\Documents\Presentations\UGISS\20180912 Italian Virtual Chapter\Demos\services.fmt'
		,	FIRSTROW = 1
		,	FORMAT = 'CSV'
		) AS T1;
GO

------------------------------------------------------------------------
-- BULK INSERT/OPENROWSET BLOB_STORAGE support
------------------------------------------------------------------------
USE TestDB;
GO

-- First we need to create a master key to protect the credentials
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Passw0rd!'; 
GO

-- Cleanup if needed
IF EXISTS (SELECT * FROM sys.external_data_sources WHERE [name] = 'AzureContainer')
	DROP EXTERNAL DATA SOURCE AzureContainer;
IF EXISTS(SELECT * FROM sys.database_scoped_credentials WHERE [name] = 'AzureCredential')
	DROP DATABASE SCOPED CREDENTIAL AzureCredential;
GO

-- We need to create a credential to access the file first
CREATE DATABASE SCOPED CREDENTIAL AzureCredential
WITH
	--	this is the name of the storage account
	IDENTITY= 'SHARED ACCESS SIGNATURE'
	--	this needs to be a SAS without the initial ? character
,			SECRET = 'sv='
GO

-- We then create an external data source mapping to an Azure Blob Storage directory (same mechanism used by polybase and Elastic Databases)
CREATE EXTERNAL DATA SOURCE AzureContainer
WITH (   
    TYPE = BLOB_STORAGE
    ,	LOCATION = 'https://azurebackdemo.blob.core.windows.net/csv'
    ,	CREDENTIAL = AzureCredential
) ;
GO

-- Create destination table, dropping it if already existing
DROP TABLE IF EXISTS dbo.ServiceStartup;
CREATE TABLE dbo.ServiceStartup (
	ServiceName	nvarchar(256) NOT NULL PRIMARY KEY
,	StartType	nvarchar(20) NOT NULL
);
GO

-- Finally used BULK INSERT to load the data from Azure Blob Storage
BULK INSERT dbo.ServiceStartup
FROM 'services.csv'
WITH (DATA_SOURCE = 'AzureContainer', FORMAT = 'CSV');
GO

SELECT * FROM dbo.ServiceStartup;
GO
