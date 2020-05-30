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
-- First of all we need to allow connectivity to Hadoop
-- exec sys.sp_configure @configname = 'hadoop connectivity', @configvalue = 7
-- 7 is Azure Blob storage, other flavors documented here
-- https://docs.microsoft.com/en-us/sql/database-engine/configure-windows/polybase-connectivity-configuration-transact-sql#arguments
--
-- Then, to allow writing to the HDFS target we need to configure it
-- exec sys.sp_configure @configname = 'allow polybase export', @configvalue = 1
--
-- Since SQL Server needs to be restarted after being reconfigured simply
-- execute script pb.04.hdfs-export-enable.en.ps1
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Create Database for Integration
------------------------------------------------------------------------
USE master;
GO
IF DB_ID('Integration') IS NOT NULL
	DROP DATABASE Integration;
GO
CREATE DATABASE Integration;
GO

------------------------------------------------------------------------
-- Create database Encryption Key
------------------------------------------------------------------------
USE [Integration];
CREATE MASTER KEY ENCRYPTION BY PASSWORD = N'Passw0rd!';
GO

------------------------------------------------------------------------
-- Create Database Scoped Credential to access the Blob Storage
------------------------------------------------------------------------
CREATE DATABASE SCOPED CREDENTIAL HDFSCredential
WITH
	IDENTITY = 'anything'
,	SECRET = 'INSERT STORAGE ACCOUNT PRIMARY OR SECONDARY KEY HERE'
GO

------------------------------------------------------------------------
-- Create External Data Source pointing to HDFS
------------------------------------------------------------------------
CREATE EXTERNAL DATA SOURCE DataLake
WITH (
	TYPE = HADOOP
,	LOCATION = 'wasbs://pbdemo@pippo.blob.core.windows.net'
,	CREDENTIAL = HDFSCredential
);
GO

------------------------------------------------------------------------
-- Create external file format
------------------------------------------------------------------------
-- Show exported data with Azure Storage Explorer
-- FORMAT TYPE: Type of format in Hadoop (DELIMITEDTEXT,  RCFILE, ORC, PARQUET).
CREATE EXTERNAL FILE FORMAT TextFileFormat
WITH (  
	FORMAT_TYPE = DELIMITEDTEXT
,	FORMAT_OPTIONS (
		FIELD_TERMINATOR ='|'
	,	USE_TYPE_DEFAULT = TRUE
	)
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
-- file formats
SELECT * FROM sys.external_file_formats;
GO

------------------------------------------------------------------------
-- Create external tables
------------------------------------------------------------------------
CREATE SCHEMA HDFS;
GO

CREATE EXTERNAL TABLE HDFS.Orders
(
	OrderID						int				NOT NULL
,	OrderDate					date			NOT NULL
,	ExpectedDeliveryDate		date			NOT NULL
,	CustomerPurchaseOrderNumber	nvarchar(20)	NULL
)
WITH
(
	LOCATION = '/pbdemo/orders'
,	DATA_SOURCE = DataLake
,	FILE_FORMAT = TextFileFormat
);
GO

CREATE EXTERNAL TABLE HDFS.OrderLines
(
	OrderLineID		int				NOT NULL
,	OrderID			int				NOT NULL
,	ItemDescription	nvarchar(100)	NOT NULL
,	Quantity		int				NOT NULL
,	UnitPrice		decimal(18,2)	NULL
)
WITH
(
	LOCATION = '/pbdemo/orderlines'
,	DATA_SOURCE = DataLake
,	FILE_FORMAT = TextFileFormat
);
GO

------------------------------------------------------------------------
-- Export some data
------------------------------------------------------------------------
--INSERT	HDFS.Orders
--SELECT	OrderID, OrderDate, ExpectedDeliveryDate, CustomerPurchaseOrderNumber
--FROM	WideWorldImporters.Sales.Orders;
--GO

--INSERT	HDFS.OrderLines
--SELECT	OrderLineID, OrderID, Description, Quantity, UnitPrice
--FROM	WideWorldImporters.Sales.OrderLines;
--GO

-----------------------------------------------------------------------
-- Query inserted data
-----------------------------------------------------------------------
-- execute including Actual Execution Plan
SELECT	*
FROM	HDFS.Orders
WHERE	YEAR(OrderDate) = 2013
GO

SELECT	OH.OrderID, OH.OrderDate, SUM(OL.Quantity * OL.UnitPrice) AS OrderTotal
FROM	HDFS.Orders AS OH
JOIN	HDFS.OrderLines AS OL
  ON	OH.OrderID = OL.OrderID
WHERE	YEAR(OH.OrderDate) = 2013
GROUP BY
	OH.OrderID, OH.OrderDate;
GO

-- hibrid
SELECT	OH.OrderID, OH.OrderDate, SUM(OL.Quantity * OL.UnitPrice) AS OrderTotal
FROM	HDFS.Orders AS OH
JOIN	WideWorldImporters.Sales.OrderLines AS OL
  ON	OH.OrderID = OL.OrderID
WHERE	YEAR(OH.OrderDate) = 2013
GROUP BY
	OH.OrderID, OH.OrderDate;
GO

-----------------------------------------------------------------------
-- Delete
-----------------------------------------------------------------------
-- not supported 
TRUNCATE TABLE HDFS.Orders;
DELETE HDFS.Orders;
GO

DROP EXTERNAL TABLE HDFS.Orders;
GO

-- of course the data is still available in HDFS

-----------------------------------------------------------------------
-- Cleanup (very easy: just drop everything!)
------------------------------------------------------------------------
USE master;
GO
IF DB_ID('Integration') IS NOT NULL
	DROP DATABASE Integration;
GO


