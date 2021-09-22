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

-- Show how to create it with Azure Data Studio
BEGIN TRY
    BEGIN TRANSACTION T8f9a2e01afa94531a2177c0721c0de7
        USE [Integration];

        CREATE MASTER KEY ENCRYPTION BY PASSWORD = N'Passw0rd!';

        CREATE DATABASE SCOPED CREDENTIAL [PolyBaseUser]
            WITH IDENTITY = N'PolyBaseUser', SECRET = N'Passw0rd!';

        CREATE EXTERNAL DATA SOURCE [SQLUX]
            WITH (LOCATION = N'sqlserver://sqlux.alphasys.local', CREDENTIAL = [PolyBaseUser]);

        EXEC(N'CREATE SCHEMA [Sales]');

        CREATE EXTERNAL TABLE [Sales].[Customer]
        (
            [CustomerID] INT NOT NULL,
            [TerritoryID] INT,
            [AccountNumber] VARCHAR(10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
            [CustomerType] NCHAR(1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
            [rowguid] UNIQUEIDENTIFIER NOT NULL,
            [ModifiedDate] DATETIME2(3) NOT NULL
        )
        WITH (LOCATION = N'[AdventureWorks].[Sales].[Customer]', DATA_SOURCE = [SQLUX]);

        CREATE EXTERNAL TABLE [Sales].[SalesOrderDetail]
        (
            [SalesOrderID] INT NOT NULL,
            [SalesOrderDetailID] INT NOT NULL,
            [CarrierTrackingNumber] NVARCHAR(25) COLLATE SQL_Latin1_General_CP1_CI_AS,
            [OrderQty] SMALLINT NOT NULL,
            [ProductID] INT NOT NULL,
            [SpecialOfferID] INT NOT NULL,
            [UnitPrice] MONEY NOT NULL,
            [UnitPriceDiscount] MONEY NOT NULL,
            [LineTotal] DECIMAL(38, 6) NOT NULL,
            [rowguid] UNIQUEIDENTIFIER NOT NULL,
            [ModifiedDate] DATETIME2(3) NOT NULL
        )
        WITH (LOCATION = N'[AdventureWorks].[Sales].[SalesOrderDetail]', DATA_SOURCE = [SQLUX]);

        CREATE EXTERNAL TABLE [Sales].[SalesOrderHeader]
        (
            [SalesOrderID] INT NOT NULL,
            [RevisionNumber] TINYINT NOT NULL,
            [OrderDate] DATETIME2(3) NOT NULL,
            [DueDate] DATETIME2(3) NOT NULL,
            [ShipDate] DATETIME2(3),
            [Status] TINYINT NOT NULL,
            [OnlineOrderFlag] BIT NOT NULL,
            [SalesOrderNumber] NVARCHAR(25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
            [PurchaseOrderNumber] NVARCHAR(25) COLLATE SQL_Latin1_General_CP1_CI_AS,
            [AccountNumber] NVARCHAR(15) COLLATE SQL_Latin1_General_CP1_CI_AS,
            [CustomerID] INT NOT NULL,
            [ContactID] INT NOT NULL,
            [SalesPersonID] INT,
            [TerritoryID] INT,
            [BillToAddressID] INT NOT NULL,
            [ShipToAddressID] INT NOT NULL,
            [ShipMethodID] INT NOT NULL,
            [CreditCardID] INT,
            [CreditCardApprovalCode] VARCHAR(15) COLLATE SQL_Latin1_General_CP1_CI_AS,
            [CurrencyRateID] INT,
            [SubTotal] MONEY NOT NULL,
            [TaxAmt] MONEY NOT NULL,
            [Freight] MONEY NOT NULL,
            [TotalDue] MONEY NOT NULL,
            [Comment] NVARCHAR(128) COLLATE SQL_Latin1_General_CP1_CI_AS,
            [rowguid] UNIQUEIDENTIFIER NOT NULL,
            [ModifiedDate] DATETIME2(3) NOT NULL
        )
        WITH (LOCATION = N'[AdventureWorks].[Sales].[SalesOrderHeader]', DATA_SOURCE = [SQLUX]);
    COMMIT TRANSACTION T8f9a2e01afa94531a2177c0721c0de7
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION T8f9a2e01afa94531a2177c0721c0de7
    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
    DECLARE @ErrorState INT = ERROR_STATE();
    RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
END CATCH;

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
SELECT	SalesOrderID, OrderDate, CustomerID
FROM	Sales.SalesOrderHeader
WHERE	OrderDate = '2004-05-01';
GO
-- things to note:
-- 1) Query is parametrized
-- 2) "Remote Query" in properties has the remote plan and statistics

-- the query predicate is pushed to remote system:
-- 1) an index on the remote table can be used
-- 2) in any case, only filtered rows are returned
-- 3) Statistics are fairly accurate 177 estimated vs 271 actual

-- let's try with a slightly different predicate
SELECT	SalesOrderID, OrderDate, CustomerID
FROM	Sales.SalesOrderHeader
WHERE	YEAR(OrderDate) = 2004;
GO
-- the predicate is still pushed down but statistics are not
-- accurate: 3k estimated vs 14k actual
-- note: with linked server was 31,5k estimated without pushdown
-- and fixed 10k estimate with OPENQUERY/sp_executesql

-- If we need more accuracy, we can create local statistics
CREATE STATISTICS stats_SalesOrderHeader
ON	Sales.SalesOrderHeader(OrderDate)
WITH FULLSCAN;
GO

-- get rid of cached plan
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO
SELECT	SalesOrderID, OrderDate, CustomerID
FROM	Sales.SalesOrderHeader
WHERE	YEAR(OrderDate) = 2004;
GO
-- now statistics are precise

-- Can't create local indexes on external tables
CREATE INDEX ix_customer on Sales.SalesOrderHeader(OrderDate);
GO

-- Can't use SCHEMABIDNING with external tables (so can't index views)
DROP VIEW IF EXISTS Sales.vOrderHeader;
GO
CREATE VIEW Sales.vOrderHeader
WITH SCHEMABINDING
AS
	SELECT	SalesOrderID, OrderDate, SalesOrderNumber
	FROM	Sales.SalesOrderHeader;
GO
--CREATE UNIQUE CLUSTERED INDEX ix_vOrderHeader ON Sales.vOrderHeader(SalesOrderID, OrderDate);
--GO

------------------------------------------------------------------------
-- Joining Tables
------------------------------------------------------------------------
-- predicate on join column
SELECT	O1.SalesOrderID, O1.OrderDate, O1.SalesOrderNumber
,		C1.CustomerID, C1.AccountNumber
FROM	Sales.SalesOrderHeader AS O1
JOIN	Sales.Customer AS C1
  ON	O1.CustomerID = C1.CustomerID
WHERE	C1.CustomerID = 11211
GO
-- predicate pushed down on both tables, orders lazy spooled (cached)
-- to improve loop join done locally

-- predicate on other column
SELECT	O1.SalesOrderID, O1.OrderDate, O1.SalesOrderNumber
,		C1.CustomerID, C1.AccountNumber
FROM	Sales.SalesOrderHeader AS O1
JOIN	Sales.Customer AS C1
  ON	O1.CustomerID = C1.CustomerID
WHERE	O1.OrderDate = '2004-05-01';
GO
-- predicate pushed down for order but not for customers
-- all customers returned and hash joined locally


------------------------------------------------------------------------
-- Referencing views
------------------------------------------------------------------------
CREATE EXTERNAL TABLE [Sales].[vProductAndDescription]
(
		[ProductID]		INT NOT NULL
	,	[Name]			NVARCHAR(50)	COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
	,	[ProductModel]	NVARCHAR(50)	COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
	,	[CultureID]		NCHAR(6)		COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
	,	[Description]	NVARCHAR(400)	COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
)
WITH (LOCATION = N'[AdventureWorks].[Production].[vProductAndDescription]', DATA_SOURCE = [SQLUX]);

-- verify in execution plan that predicate is effectively pushed down
SELECT	*
FROM	[Sales].[vProductAndDescription]
WHERE	[Description] LIKE '%Cross%'
  AND	CultureID = 'en';
GO

-----------------------------------------------------------------------
-- Cleanup (very easy: just drop everything!)
------------------------------------------------------------------------
USE master;
GO
IF DB_ID('Integration') IS NOT NULL
	DROP DATABASE Integration;
GO


