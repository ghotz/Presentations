------------------------------------------------------------------------
-- Copyright:   2019 Gianluca Hotz
-- License:     MIT License
--              Permission is hereby granted, free of charge, to any
--              person obtaining a copy of this software and associated
--              documentation files (the "Software"), to deal in the
--              Software without restriction, including without
--              limitation the rights to use, copy, modify, merge,
--              publish, distribute, sublicense, and/or sell copies of
--              the Software, and to permit persons to whom the
--              Software is furnished to do so, subject to the
--              following conditions:
--              The above copyright notice and this permission notice
--              shall be included in all copies or substantial portions
--              of the Software.
--              THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
--              ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
--              LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
--              FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
--              EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
--              FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
--              AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--              OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
--              OTHER DEALINGS IN THE SOFTWARE.
-- Credits:    
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Create External Table
------------------------------------------------------------------------
USE master;
GO
IF DB_ID('Integration') IS NOT NULL
	DROP DATABASE Integration;
GO
CREATE DATABASE Integration;
GO

USE [Integration];
GO

------------------------------------------------------------------------
-- Create database Encryption Key
------------------------------------------------------------------------
CREATE MASTER KEY ENCRYPTION BY PASSWORD = N'Passw0rd!';
GO

------------------------------------------------------------------------
-- Create Database Scoped Credential to access Azure SQL Database
------------------------------------------------------------------------
CREATE DATABASE SCOPED CREDENTIAL AzureCredential
WITH IDENTITY = N'PBUser', SECRET = 'Passw0rd!';
GO

------------------------------------------------------------------------
-- Create External Data Source pointing to Azure SQL Database
------------------------------------------------------------------------
-- Plase note CONNECTION_OPTIONS shouldn't be necessary under
-- normal conditions, but it seems there's a regression in 2019 RTM
-- that causes ODBC error "Database is invalid or cannot be accessed"
-- more info https://github.com/MicrosoftDocs/sql-docs/issues/3727
-- The problem has been fixed in RTM GDR hotfix
------------------------------------------------------------------------
CREATE EXTERNAL DATA SOURCE AzureSQLDB
WITH (
	LOCATION = 'sqlserver://polybase.database.windows.net'
,	CREDENTIAL = AzureCredential
--,	CONNECTION_OPTIONS = 'Database=pbdemo'
);
GO

------------------------------------------------------------------------
-- Create external tables
------------------------------------------------------------------------
CREATE SCHEMA SalesLT;
GO

CREATE EXTERNAL TABLE SalesLT.Customer(
	CustomerID		int NOT NULL,
	NameStyle		bit NOT NULL,
	Title			nvarchar(8) NULL,
	FirstName		nvarchar(50) NOT NULL,
	MiddleName		nvarchar(50) NULL,
	LastName		nvarchar(50) NOT NULL,
	Suffix			nvarchar(10) NULL,
	CompanyName		nvarchar(128) NULL,
	SalesPerson		nvarchar(256) NULL,
	EmailAddress	nvarchar(50) NULL,
	Phone			nvarchar(25) NULL,
	PasswordHash	varchar(128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	PasswordSalt	varchar(10)  COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	rowguid			uniqueidentifier NOT NULL,
	ModifiedDate	datetime NOT NULL
)
WITH
(
	LOCATION = N'[pbdemo].[SalesLT].[Customer]'
,	DATA_SOURCE = AzureSQLDB
);
GO

------------------------------------------------------------------------
-- External Resources Metadata
------------------------------------------------------------------------
USE Integration;
GO
-- database scoped credentials
SELECT * FROM sys.database_credentials;
SELECT * FROM sys.database_scoped_credentials;
GO

-- data sources
SELECT * FROM sys.external_data_sources;
GO

------------------------------------------------------------------------
-- Explore Remote Metadata
------------------------------------------------------------------------
USE Integration;
GO
-- tables are mapped inside the database like regular tables
SELECT * FROM sys.objects WHERE is_ms_shipped = 0;
GO

-- they are exposed as regular BASE TABLEs
SELECT	*
FROM	INFORMATION_SCHEMA.TABLES AS T1
JOIN	INFORMATION_SCHEMA.COLUMNS AS C1
  ON	T1.TABLE_CATALOG = C1.TABLE_CATALOG
 AND	T1.TABLE_SCHEMA = C1.TABLE_SCHEMA
 AND	T1.TABLE_NAME = C1.TABLE_NAME;
 GO

-- column is_external can be used to differentiate them
SELECT
	SCHEMA_NAME(T1.[schema_id]) AS table_schema
,	T1.[name] AS table_name
,	T1.[type_desc] AS table_type_desc
,	T1.is_external
,	C1.*
FROM	sys.tables AS T1
JOIN	sys.columns AS C1
  ON	T1.[object_id] = C1.[object_id];
GO

-- or catalog view sys.external_tables which is a specialization sys.objects
SELECT * FROM sys.external_tables;
GO

------------------------------------------------------------------------
-- Access the external data
------------------------------------------------------------------------
USE Integration;
GO
-- execute including Actual Execution Plan
SELECT	*
FROM	SalesLT.Customer
WHERE	SalesPerson = N'adventure-works\david8';
GO

------------------------------------------------------------------------
-- Joining Tables (all virtual)
-- Salses.SalesOrderHeader  on SQL Server 2017 (Linux)
-- SalesLT.Customer         on Azure SQL Database
------------------------------------------------------------------------
SELECT	O1.SalesOrderID, O1.OrderDate, O1.SalesOrderNumber
,		C1.CustomerID, C1.FirstName, C1.Lastname, C1.CompanyName
FROM	Sales.SalesOrderHeader AS O1
JOIN	SalesLT.Customer AS C1
  ON	O1.CustomerID = C1.CustomerID
WHERE	C1.SalesPerson = N'adventure-works\david8';
GO

------------------------------------------------------------------------
-- Joining Tables (all virtual)
-- Sales.SalesOrderHeader  on SQL Server 2017 (Linux)
-- Sales.SalesOrderDetail  on SQL Server 2017 (Linux)
-- SalesLT.Customer         on Azure SQL Database
------------------------------------------------------------------------
SELECT	O1.SalesOrderID, O1.OrderDate, O1.SalesOrderNumber
,		D1.ProductID, D1.OrderQty, D1.LineTotal
,		C1.CustomerID, C1.FirstName, C1.Lastname, C1.CompanyName
FROM	Sales.SalesOrderHeader AS O1
JOIN	Sales.SalesOrderDetail AS D1
  ON	O1.SalesOrderID = D1.SalesOrderID
JOIN	SalesLT.Customer AS C1
  ON	O1.CustomerID = C1.CustomerID
WHERE	C1.SalesPerson = N'adventure-works\david8';
GO

-----------------------------------------------------------------------
-- Cleanup (very easy: just drop everything!)
------------------------------------------------------------------------
USE master;
GO
IF DB_ID('Integration') IS NOT NULL
	DROP DATABASE Integration;
GO
