------------------------------------------------------------------------
--	Script:			en.03.cardinality-estimator.sql
--	Description:	Cardinality Estimator
--	Author:			Gianluca Hotz (SolidQ)
--	Copyright:		Attribution-NonCommercial-ShareAlike 3.0
------------------------------------------------------------------------

--	Based on examples in Benjamin Nevarez article on http://www.sqlperformance.com
--	"A First Look at the New SQL Server Cardinality Estimator"
--	http://www.sqlperformance.com/2013/12/t-sql-queries/a-first-look-at-the-new-sql-server-cardinality-estimator

--
--	Same table predicate independence
--

--	Revert any changes to original compatibility level
ALTER DATABASE AdventureWorks2012
SET COMPATIBILITY_LEVEL = 110;
GO
USE AdventureWorks2012;
GO

--	Execute and look at plan: estimated 196 actual 196
SELECT * FROM Person.Address WHERE City = 'Burbank';
GO

--	Execute and look at plan: estimated 194 actual 194
SELECT * FROM Person.Address WHERE PostalCode = '91502';
GO

--	Execute and look at plan: estimated 1,93862 actual 194
SELECT * FROM Person.Address WHERE City = 'Burbank' AND PostalCode = '91502';
GO

--	Estimation comes from assuming total indepence
--	Note: total correlation would yield 194
SELECT (196 * 194) / 19614.0 -- 19614 = total rows
GO

--	Change compatibility level to use new CE
ALTER DATABASE AdventureWorks2012
SET COMPATIBILITY_LEVEL = 120;
GO

--	Execute and look at plan: estimated 19,3931 actual 194
SELECT * FROM Person.Address WHERE City = 'Burbank' AND PostalCode = '91502';
GO

--	Estimation comes from assuming some correlation
SELECT (194/19614.0) * SQRT(196/19614.0) * 19614 -- 19614 = total rows
GO

--	Check also CardinalityEstimationModelVersion property in XML Plan

--	Run the query with 70 CE
SELECT * FROM Person.Address WHERE City = 'Burbank' AND PostalCode = '91502'
OPTION (QUERYTRACEON 9481);
--OPTION (USE HINT('FORCE_LEGACY_CARDINALITY_ESTIMATION')) -- SQL Server 2016 SP1+
GO

--
--	Ascending data
--

--	Revert any changes to original compatibility level
ALTER DATABASE AdventureWorks2012
SET COMPATIBILITY_LEVEL = 110;
GO
USE AdventureWorks2012;
GO

--	Create test table
IF OBJECT_ID('dbo.SalesOrderHeader') IS NOT NULL
	DROP TABLE dbo.SalesOrderHeader;
GO
CREATE TABLE dbo.SalesOrderHeader (
    SalesOrderID			int NOT NULL,
    RevisionNumber			tinyint NOT NULL,
    OrderDate				datetime NOT NULL,
    DueDate					datetime NOT NULL,
    ShipDate				datetime NULL,
    [Status]				tinyint NOT NULL,
    OnlineOrderFlag			dbo.Flag NOT NULL,
    SalesOrderNumber		nvarchar(25) NOT NULL,
    PurchaseOrderNumber		dbo.OrderNumber NULL,
    AccountNumber			dbo.AccountNumber NULL,
    CustomerID				int NOT NULL,
	ContactID				int NOT NULL,
    SalesPersonID			int NULL,
    TerritoryID				int NULL,
    BillToAddressID			int NOT NULL,
    ShipToAddressID			int NOT NULL,
    ShipMethodID			int NOT NULL,
    CreditCardID			int NULL,
    CreditCardApprovalCode	varchar(15) NULL,
    CurrencyRateID			int NULL,
    SubTotal				money NOT NULL,
    TaxAmt					money NOT NULL,
    Freight					money NOT NULL,
    TotalDue				money NOT NULL,
    Comment					nvarchar(128) NULL,
    rowguid					uniqueidentifier NOT NULL,
    ModifiedDate			datetime NOT NULL
);

--	Insert values in table
INSERT	dbo.SalesOrderHeader
SELECT	*
FROM	Sales.SalesOrderHeader 
WHERE	OrderDate < '2004-07-20 00:00:00.000';
GO

--	Create index on order date to have fresh statistics
CREATE INDEX IX_OrderDate ON dbo.SalesOrderHeader(OrderDate);
GO

--	Execute and look at plan: estimated 35 actual 35
SELECT * FROM dbo.SalesOrderHeader WHERE OrderDate = '2004-07-19 00:00:00.000';
GO

--	Check extimated rows in statistics for specified date (35)
DBCC SHOW_STATISTICS('dbo.SalesOrderHeader', 'IX_OrderDate');
GO

--	Insert new data
--	(30 rows, less than 20% of total rows, don't trigger statistics update)
INSERT	dbo.SalesOrderHeader
SELECT	*
FROM	Sales.SalesOrderHeader 
WHERE	OrderDate = '2004-07-20 00:00:00.000';
GO

--	Execute and look at plan: estimated 1 actual 30
SELECT * FROM dbo.SalesOrderHeader WHERE OrderDate = '2004-07-20 00:00:00.000';
GO

--	Check extimated rows in statistics for specified date
DBCC SHOW_STATISTICS('dbo.SalesOrderHeader', 'IX_OrderDate');
GO

--	Change compatibility level to use new CE
ALTER DATABASE AdventureWorks2012
SET COMPATIBILITY_LEVEL = 120;
GO

--	Execute and look at plan: estimated 27,9631 actual 30
SELECT * FROM dbo.SalesOrderHeader WHERE OrderDate = '2008-07-20 00:00:00.000';
GO

--	Check extimated rows in statistics for specified date
DBCC SHOW_STATISTICS('dbo.SalesOrderHeader', 'IX_OrderDate');
GO

--	Estimation comes from density multiplied by total rows
SELECT 0.0008992806 * 31095 -- 31095 = total rows
GO

--
-- Cleanup
--
IF OBJECT_ID('dbo.SalesOrderHeader') IS NOT NULL
	DROP TABLE dbo.SalesOrderHeader;
GO
ALTER DATABASE AdventureWorks2012
SET COMPATIBILITY_LEVEL = 110;
GO
