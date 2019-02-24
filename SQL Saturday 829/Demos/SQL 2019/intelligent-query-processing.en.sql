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
-- Credits:     Saverio Lorenzini (some Adaptive Query processing demos)
--				Joe Sack https://blogs.msdn.microsoft.com/sqlserverstorageengine/2018/09/24/introducing-batch-mode-on-rowstore
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Batch Execution mode
------------------------------------------------------------------------

-- Note: extend the schema with the following script
-- https://github.com/joesackmsft/Conferences/blob/master/IQPDemos/Intelligent%20QP%20Demos%20Enlarging%20WideWorldImportersDW.sql
USE WideWorldImportersDW;
GO
-- let's see standard behaviour before 2019
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 140;
GO

-- See execution plan: batch mode on rowstore eligible but not used 
SELECT
	[Tax Rate], [Lineage Key], [Salesperson Key]
,	SUM([Quantity]) AS SUM_QTY, SUM([Unit Price]) AS SUM_BASE_PRICE, COUNT(*) AS COUNT_ORDER
FROM	[Fact].[OrderHistoryExtended]
WHERE	[Order Date Key] <= DATEADD(dd, -73, '2015-11-13')
GROUP BY	[Tax Rate], [Lineage Key], [Salesperson Key]
ORDER BY	[Tax Rate], [Lineage Key], [Salesperson Key]
OPTION (RECOMPILE);
GO

-- Let's change to 2019 beaviour  (by default table variable deferred compilation is on)
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 150;
GO

-- See execution plan: batch mode on rowstore eligible and now used automatically
SELECT
	[Tax Rate], [Lineage Key], [Salesperson Key]
,	SUM([Quantity]) AS SUM_QTY, SUM([Unit Price]) AS SUM_BASE_PRICE, COUNT(*) AS COUNT_ORDER
FROM	[Fact].[OrderHistoryExtended]
WHERE	[Order Date Key] <= DATEADD(dd, -73, '2015-11-13')
GROUP BY	[Tax Rate], [Lineage Key], [Salesperson Key]
ORDER BY	[Tax Rate], [Lineage Key], [Salesperson Key]
OPTION (RECOMPILE);
GO

-- The functionality can be disabled independently from the compatibility level
-- at database level:
-- ALTER DATABASE SCOPED CONFIGURATION SET BATCH_MODE_ON_ROWSTORE = ON|OFF
-- at query level:
-- OPTION (USE HINT('DISALLOW_BATCH_MODE'))
-- OPTION (USE HINT('ALLOW_BATCH_MODE'))

-- Compare execution plans with query level hints
SELECT
	[Tax Rate], [Lineage Key], [Salesperson Key]
,	SUM([Quantity]) AS SUM_QTY, SUM([Unit Price]) AS SUM_BASE_PRICE, COUNT(*) AS COUNT_ORDER
FROM	[Fact].[OrderHistoryExtended]
WHERE	[Order Date Key] <= DATEADD(dd, -73, '2015-11-13')
GROUP BY	[Tax Rate], [Lineage Key], [Salesperson Key]
ORDER BY	[Tax Rate], [Lineage Key], [Salesperson Key]
OPTION (RECOMPILE, USE HINT('DISALLOW_BATCH_MODE'));

SELECT
	[Tax Rate], [Lineage Key], [Salesperson Key]
,	SUM([Quantity]) AS SUM_QTY, SUM([Unit Price]) AS SUM_BASE_PRICE, COUNT(*) AS COUNT_ORDER
FROM	[Fact].[OrderHistoryExtended]
WHERE	[Order Date Key] <= DATEADD(dd, -73, '2015-11-13')
GROUP BY	[Tax Rate], [Lineage Key], [Salesperson Key]
ORDER BY	[Tax Rate], [Lineage Key], [Salesperson Key]
OPTION (RECOMPILE, USE HINT('ALLOW_BATCH_MODE'));
GO

------------------------------------------------------------------------
-- Adaptive Query processing
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Batch mode memory grant feedback
------------------------------------------------------------------------
USE WideWorldImportersDW;
GO

-- let's create a test procedure
CREATE OR ALTER PROCEDURE [FactOrderByLineageKey]
	@LineageKey INT 
AS
	SELECT  fo.[Order Key], fo.Description
	FROM    [Fact].[Order] AS [fo]
	INNER JOIN [Dimension].[Stock Item] AS [si] 
	ON [fo].[Stock Item Key] = [si].[Stock Item Key]
	WHERE   [fo].[Lineage Key] = @LineageKey
	AND [si].[Lead Time Days] > 0
	ORDER BY fo.[Stock Item Key], fo.[Order Date Key]
	OPTION (MAXDOP 1);
GO

-- let's see standard behaviour before 2017
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 130;
GO

-- first xecution, include execution plan and check the tip in the
-- SELECT operator and MemoryGrantInfo in properties
EXEC [FactOrderByLineageKey] 1;
GO

-- clear procedure cache and change compatibility level (by default memory grant feedback is on)
ALTER DATABASE [WideWorldImportersDW] SET COMPATIBILITY_LEVEL = 140;
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

-- afetr first execution the plan is the same as before
-- but on second execution the tip disappears and MemoryGrantInfo
-- now shows much less memory granted and used
EXEC [FactOrderByLineageKey] 1;
GO

-- let's clear again the cache and see what happens when a new 
-- execution requires more memory after feedback lowered it
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
EXEC [FactOrderByLineageKey] 1;
EXEC [FactOrderByLineageKey] 1;
EXEC [FactOrderByLineageKey] 9;
EXEC [FactOrderByLineageKey] 9;
GO

-- The functionality can be disabled independently from the compatibility level
-- at database level:
-- ALTER DATABASE SCOPED CONFIGURATION SET BATCH_MODE_MEMORY_GRANT_FEEDBACK = ON|OFF
-- at query level:
-- OPTION (USE HINT('DISABLE_BATCH_MODE_MEMORY_GRANT_FEEDBACK'))

-- Note: the sort spill happens in "batch mode" so no detailed information are
-- available directly in the plan about how much data has been spilled
-- (normally available with "row mode"); also,the granted memory is higher
-- than the requested memory in "batch mode" spills, this is expected.
-- More details on the internals, including which XE to capture here:
-- http://www.queryprocessor.com/sort-spill-memory-and-adaptive-memory-grant-feedback

-- Note: row mode memory grant feedback has been recently introudced in Azure SQL Database

------------------------------------------------------------------------
-- Row mode memory grant feedback
------------------------------------------------------------------------
USE WideWorldImporters;
GO

-- let's see standard behaviour before 2019
ALTER DATABASE WideWorldImporters SET COMPATIBILITY_LEVEL = 140;
GO

-- Run query and look at execution plan
SELECT 
	OD.CustomerID, OD.CustomerPurchaseOrderNumber,
	OD.InternalComments, OL.Quantity, OL.UnitPrice
FROM	[Sales].[Orders] AS OD
JOIN	[Sales].[OrderLines] AS OL
  ON	OD.OrderID = OL.OrderID
ORDER BY OD.[Comments];
GO

-- Let's change to 2019 beaviour  (by default row memory grant feedback is on)
ALTER DATABASE WideWorldImporters SET COMPATIBILITY_LEVEL = 150;
GO

-- Run query and look at execution plan
SELECT 
	OD.CustomerID,OD.CustomerPurchaseOrderNumber,
	OD.InternalComments,OL.Quantity,OL.UnitPrice
FROM	[Sales].[Orders] OD
JOIN	[Sales].[OrderLines] OL
  ON	OD.OrderID = OL.OrderID
ORDER BY OD.[Comments];
GO

-- The functionality can be disabled independently from the compatibility level
-- at database level:
-- ALTER DATABASE SCOPED CONFIGURATION SET ROW_MODE_MEMORY_GRANT_FEEDBACK = ON|OFF
-- at query level:
-- OPTION (USE HINT('DISABLE_ROW_MODE_MEMORY_GRANT_FEEDBACK'))

------------------------------------------------------------------------
-- Batch mode adaptive joins
------------------------------------------------------------------------
USE WideWorldImportersDW;
GO

-- cleanup
DELETE	[Fact].[Order] WHERE Quantity = 361;
INSERT	[Fact].[Order] ([City Key], [Customer Key], [Stock Item Key], [Order Date Key], [Picked Date Key], [Salesperson Key], [Picker Key], [WWI Order ID], [WWI Backorder ID], [Description], Package, Quantity, [Unit Price], [Tax Rate], [Total Excluding Tax], [Tax Amount], [Total Including Tax], [Lineage Key])
SELECT	TOP 5 [City Key], [Customer Key], [Stock Item Key], [Order Date Key], [Picked Date Key], [Salesperson Key], [Picker Key], [WWI Order ID], [WWI Backorder ID], [Description], Package, 361, [Unit Price], [Tax Rate], [Total Excluding Tax], [Tax Amount], [Total Including Tax], [Lineage Key]
FROM	[Fact].[Order];
UPDATE STATISTICS [Fact].[Order];
GO

-- let's see standard behaviour before 2017
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 130;
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

-- show execution plan
-- many rows (206), hash match is better
SELECT  [fo].[Order Key], [si].[Lead Time Days], [fo].[Quantity]
FROM    [Fact].[Order] AS [fo]
INNER JOIN [Dimension].[Stock Item] AS [si] 
	ON [fo].[Stock Item Key] = [si].[Stock Item Key]
WHERE   [fo].[Quantity] = 360;
-- few rows (5), inner loop is better
SELECT  [fo].[Order Key], [si].[Lead Time Days], [fo].[Quantity]
FROM    [Fact].[Order] AS [fo]
INNER JOIN [Dimension].[Stock Item] AS [si] 
	ON [fo].[Stock Item Key] = [si].[Stock Item Key]
WHERE   [fo].[Quantity] = 361;
GO

-- let's change to 2017 beaviour  (by default adaptive joins are on)
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 140;
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

-- adaptive join, SHOW LIVE QUERY STATISTICS and properties
-- Actual Join Type = hashmatch, threshold 68.8, Clustered Index Scan executed
SELECT  [fo].[Order Key], [si].[Lead Time Days], [fo].[Quantity]
FROM    [Fact].[Order] AS [fo]
INNER JOIN [Dimension].[Stock Item] AS [si] 
	ON [fo].[Stock Item Key] = [si].[Stock Item Key]
WHERE   [fo].[Quantity] = 360;
GO

-- Actual Join Type = NestedLoops, threshold 85, Clustered Index Seek executed
SELECT  [fo].[Order Key], [si].[Lead Time Days], [fo].[Quantity]
FROM    [Fact].[Order] AS [fo]
INNER JOIN [Dimension].[Stock Item] AS [si] 
	ON [fo].[Stock Item Key] = [si].[Stock Item Key]
WHERE   [fo].[Quantity] = 361;
GO

-- The functionality can be disabled independently from the compatibility level
-- ALTER DATABASE SCOPED CONFIGURATION SET BATCH_MODE_ADAPTIVE_JOINS = ON;

------------------------------------------------------------------------
-- Interleaved Execution
------------------------------------------------------------------------
USE WideWorldImportersDW;
GO

-- multi-statement table-valued function
CREATE OR ALTER FUNCTION [Fact].[WhatIfOutlierEventQuantity](@event VARCHAR(15), @beginOrderDateKey DATE, @endOrderDateKey DATE)
RETURNS @OutlierEventQuantity TABLE (
	[Order Key] [bigint],
	[City Key] [int] NOT NULL,
	[Customer Key] [int] NOT NULL,
	[Stock Item Key] [int] NOT NULL,
	[Order Date Key] [date] NOT NULL,
	[Picked Date Key] [date] NULL,
	[Salesperson Key] [int] NOT NULL,
	[Picker Key] [int] NULL,
	[OutlierEventQuantity] [int] NOT NULL)
AS 
BEGIN

-- Valid @event values
	-- 'Mild Recession'
	-- 'Hurricane - South Atlantic'
	-- 'Hurricane - East South Central'
	-- 'Hurricane - West South Central'
	IF @event = 'Mild Recession'
    INSERT  @OutlierEventQuantity
	SELECT [o].[Order Key], [o].[City Key], [o].[Customer Key],
           [o].[Stock Item Key], [o].[Order Date Key], [o].[Picked Date Key],
           [o].[Salesperson Key], [o].[Picker Key], 
           CASE
			WHEN [o].[Quantity] > 2 THEN [o].[Quantity] * .5
			ELSE [o].[Quantity]
		   END 
	FROM [Fact].[Order] AS [o]
	INNER JOIN [Dimension].[City] AS [c]
		ON [c].[City Key] = [o].[City Key]

	IF @event = 'Hurricane - South Atlantic'
    INSERT  @OutlierEventQuantity
	SELECT [o].[Order Key], [o].[City Key], [o].[Customer Key],
           [o].[Stock Item Key], [o].[Order Date Key], [o].[Picked Date Key],
           [o].[Salesperson Key], [o].[Picker Key], 
           CASE
			WHEN [o].[Quantity] > 10 THEN [o].[Quantity] * .5
			ELSE [o].[Quantity]
		   END 
	FROM [Fact].[Order] AS [o]
	INNER JOIN [Dimension].[City] AS [c]
		ON [c].[City Key] = [o].[City Key]
	WHERE [c].[State Province] IN
	('Florida', 'Georgia', 'Maryland', 'North Carolina',
	'South Carolina', 'Virginia', 'West Virginia',
	'Delaware')
	AND [o].[Order Date Key] BETWEEN @beginOrderDateKey AND @endOrderDateKey

	IF @event = 'Hurricane - East South Central'
    INSERT  @OutlierEventQuantity
	SELECT [o].[Order Key], [o].[City Key], [o].[Customer Key],
           [o].[Stock Item Key], [o].[Order Date Key], [o].[Picked Date Key],
           [o].[Salesperson Key], [o].[Picker Key], 
           CASE
			WHEN [o].[Quantity] > 50 THEN [o].[Quantity] * .5
			ELSE [o].[Quantity]
		   END
	FROM [Fact].[Order] AS [o]
	INNER JOIN [Dimension].[City] AS [c]
		ON [c].[City Key] = [o].[City Key]
	INNER JOIN [Dimension].[Stock Item] AS [si]
	ON [si].[Stock Item Key] = [o].[Stock Item Key]
	WHERE [c].[State Province] IN
	('Alabama', 'Kentucky', 'Mississippi', 'Tennessee')
	AND [si].[Buying Package] = 'Carton'
	AND [o].[Order Date Key] BETWEEN @beginOrderDateKey AND @endOrderDateKey

	IF @event = 'Hurricane - West South Central'
    INSERT  @OutlierEventQuantity
	SELECT [o].[Order Key], [o].[City Key], [o].[Customer Key],
           [o].[Stock Item Key], [o].[Order Date Key], [o].[Picked Date Key],
           [o].[Salesperson Key], [o].[Picker Key], 
           CASE
		    WHEN [cu].[Customer] = 'Unknown' THEN 0
			WHEN [cu].[Customer] <> 'Unknown' AND
			 [o].[Quantity] > 10 THEN [o].[Quantity] * .5
			ELSE [o].[Quantity]
		   END
	FROM [Fact].[Order] AS [o]
	INNER JOIN [Dimension].[City] AS [c]
		ON [c].[City Key] = [o].[City Key]
	INNER JOIN [Dimension].[Customer] AS [cu]
	ON [cu].[Customer Key] = [o].[Customer Key]
	WHERE [c].[State Province] IN
	('Arkansas', 'Louisiana', 'Oklahoma', 'Texas')
	AND [o].[Order Date Key] BETWEEN @beginOrderDateKey AND @endOrderDateKey

    RETURN
END
GO

-- let's see standard behaviour before 2017
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 130;
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

-- explore execution plan: 100 rows estimated from TVF, 231417 returned, spills (with compatibility level 130)
SELECT  [fo].[Order Key], [fo].[Description], [fo].[Package], [fo].[Quantity], [foo].[OutlierEventQuantity]
FROM    [Fact].[Order] AS [fo]
INNER JOIN [Fact].[WhatIfOutlierEventQuantity]('Mild Recession','1-01-2013','10-15-2014') AS [foo] 
							ON [fo].[Order Key] = [foo].[Order Key]
                            AND [fo].[City Key] = [foo].[City Key]
                            AND [fo].[Customer Key] = [foo].[Customer Key]
                            AND [fo].[Stock Item Key] = [foo].[Stock Item Key]
                            AND [fo].[Order Date Key] = [foo].[Order Date Key]
                            AND [fo].[Picked Date Key] = [foo].[Picked Date Key]
                            AND [fo].[Salesperson Key] = [foo].[Salesperson Key]
                            AND [fo].[Picker Key] = [foo].[Picker Key]
INNER JOIN [Dimension].[Stock Item] AS [si] 
ON [fo].[Stock Item Key] = [si].[Stock Item Key]
WHERE   [si].[Lead Time Days] > 0 AND [fo].[Quantity] > 50;
GO

ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 140;
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

-- explore execution plan: 231417 rows estimated and returned from TVF, no spills
SELECT  [fo].[Order Key], [fo].[Description], [fo].[Package], [fo].[Quantity], [foo].[OutlierEventQuantity]
FROM    [Fact].[Order] AS [fo]
INNER JOIN [Fact].[WhatIfOutlierEventQuantity]('Mild Recession','1-01-2013','10-15-2014') AS [foo] 
							ON [fo].[Order Key] = [foo].[Order Key]
                            AND [fo].[City Key] = [foo].[City Key]
                            AND [fo].[Customer Key] = [foo].[Customer Key]
                            AND [fo].[Stock Item Key] = [foo].[Stock Item Key]
                            AND [fo].[Order Date Key] = [foo].[Order Date Key]
                            AND [fo].[Picked Date Key] = [foo].[Picked Date Key]
                            AND [fo].[Salesperson Key] = [foo].[Salesperson Key]
                            AND [fo].[Picker Key] = [foo].[Picker Key]
INNER JOIN [Dimension].[Stock Item] AS [si] 
ON [fo].[Stock Item Key] = [si].[Stock Item Key]
WHERE   [si].[Lead Time Days] > 0 AND [fo].[Quantity] > 50;
GO

-- The functionality can be disabled independently from the compatibility level
-- ALTER DATABASE SCOPED CONFIGURATION SET INTERLEAVED_EXECUTION_TVF = ON;

------------------------------------------------------------------------
-- Table Variable Deferred Compilation
------------------------------------------------------------------------
USE WideWorldImportersDW;
GO

-- Let's see standard behaviour before 2019
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 140;
GO

-- Check in the execution plan that the row estimate
-- from the TV is 1 and that leads to an loop join
DECLARE	@Orders TABLE (
			[Order Key] INT NOT NULL
		,	Quantity INT NOT NULL);

INSERT	@Orders
SELECT	O.[Order Key], O.Quantity
FROM	Fact.[Order] AS O
WHERE	O.Quantity = 5;

SELECT	O1.[Order Key], O1.Quantity, O2.[Description]
FROM	@Orders AS O1
JOIN	Fact.[Order] AS O2
  ON	O1.[Order Key] = O2.[Order Key]
GO

-- Let's change to 2019 beaviour  (by default table variable deferred compilation is on)
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 150;
GO

-- Check in the execution plan that the row estimate
-- from the TV is correct and that leads to an hash join
DECLARE	@Orders TABLE (
			[Order Key] INT NOT NULL
		,	Quantity INT NOT NULL);

INSERT	@Orders
SELECT	O.[Order Key], O.Quantity
FROM	Fact.[Order] AS O
WHERE	O.Quantity = 5;

SELECT	O1.[Order Key], O1.Quantity, O2.[Description]
FROM	@Orders AS O1
JOIN	Fact.[Order] AS O2
  ON	O1.[Order Key] = O2.[Order Key]
GO

-- The functionality can be disabled independently from the compatibility level
-- at database level
-- ALTER DATABASE SCOPED CONFIGURATION SET DEFERRED_COMPILATION_TV = ON;
-- at query level
DECLARE	@Orders TABLE (
			[Order Key] INT NOT NULL
		,	Quantity INT NOT NULL);

INSERT	@Orders
SELECT	O.[Order Key], O.Quantity
FROM	Fact.[Order] AS O
WHERE	O.Quantity = 5;

SELECT	O1.[Order Key], O1.Quantity, O2.[Description]
FROM	@Orders AS O1
JOIN	Fact.[Order] AS O2
  ON	O1.[Order Key] = O2.[Order Key]
OPTION	(USE HINT('DISABLE_DEFERRED_COMPILATION_TV'));
GO

------------------------------------------------------------------------
-- APPROX_COUNT_DISTINCT
------------------------------------------------------------------------
USE WideWorldImportersDW;
GO

-- Verify that the results are not precise and that in the execution plan
-- the first one is cheaper and faster
SELECT	D.[Calendar Year Label], APPROX_COUNT_DISTINCT(O.[Order Key])
FROM	Fact.[Order] AS O
JOIN	Dimension.[Date] AS D
ON		O.[Order Date Key] = D.[Date]
GROUP BY D.[Calendar Year Label]

SELECT	D.[Calendar Year Label], COUNT(DISTINCT O.[Order Key])
FROM	Fact.[Order] AS O
JOIN	Dimension.[Date] AS D
ON		O.[Order Date Key] = D.[Date]
GROUP BY D.[Calendar Year Label]
GO

-- Compare execution time and distinct counts
SELECT COUNT(DISTINCT [WWI Order ID])
FROM [Fact].[OrderHistoryExtended]
OPTION (USE HINT('DISALLOW_BATCH_MODE'), RECOMPILE); -- Isolating out BMOR

SELECT APPROX_COUNT_DISTINCT([WWI Order ID])
FROM [Fact].[OrderHistoryExtended]
OPTION (USE HINT('DISALLOW_BATCH_MODE'), RECOMPILE); -- Isolating out BMOR

------------------------------------------------------------------------
-- Scalar UDF inlining
------------------------------------------------------------------------
USE WideWorldImportersDW;
GO

CREATE OR ALTER FUNCTION
	dbo.customer_category(@CustomerKey INT) 
RETURNS CHAR(10) AS
BEGIN
	DECLARE	@total_amount DECIMAL(18,2);
	DECLARE	@category CHAR(10);

	SELECT	@total_amount = SUM([Total Including Tax]) 
	FROM	[Fact].[OrderHistory]
	WHERE	[Customer Key] = @CustomerKey;

	IF @total_amount < 500000
		SET @category = 'REGULAR';
	ELSE IF @total_amount < 1000000
		SET @category = 'GOLD';
	ELSE 
		SET @category = 'PLATINUM';

	RETURN @category;
END
GO

-- Let's change to 2019 beaviour  (by default scalar UDF automatic inlining is on)
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 150;
GO

-- Before (show actual query execution plan for legacy behavior)
SELECT TOP 100
		[Customer Key], [Customer],
       dbo.customer_category([Customer Key]) AS [Discount Price]
FROM [Dimension].[Customer]
ORDER BY [Customer Key]
OPTION (RECOMPILE, USE HINT('DISABLE_TSQL_SCALAR_UDF_INLINING'));

-- After (show actual query execution plan for Scalar UDF Inlining)
SELECT TOP 100
		[Customer Key], [Customer],
       dbo.customer_category([Customer Key]) AS [Discount Price]
FROM [Dimension].[Customer]
ORDER BY [Customer Key]
OPTION (RECOMPILE);
