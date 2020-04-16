------------------------------------------------------------------------
-- Copyright:   2020 Gianluca Hotz
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
-- Intelligent Query processing (SQL Server 2019+ only)
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Batch mode on Rowstore
--
-- Credits
-- https://github.com/microsoft/sql-server-samples/blob/master/samples/features/intelligent-query-processing/IQP%20Demo%20-%20Batch%20Mode%20on%20Rowstore.sql
-- Note: database needs to be enlarged with the following script
-- https://github.com/microsoft/sql-server-samples/blob/master/samples/features/intelligent-query-processing/IQP%20Demo%20Setup%20-%20Enlarging%20WideWorldImportersDW.sql
------------------------------------------------------------------------
USE WideWorldImportersDW;
GO

-- let's see standard behaviour before 2019
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 140;
GO

-- execute and look at execution plan
SELECT [Tax Rate],
	[Lineage Key],
	[Salesperson Key],
	SUM([Quantity]) AS SUM_QTY,
	SUM([Unit Price]) AS SUM_BASE_PRICE,
	COUNT(*) AS COUNT_ORDER
FROM [Fact].[OrderHistoryExtended]
WHERE [Order Date Key] <= DATEADD(dd, -73, '2015-11-13')
GROUP BY [Tax Rate],
	[Lineage Key],
	[Salesperson Key]
ORDER BY [Tax Rate],
	[Lineage Key],
	[Salesperson Key]
--OPTION (RECOMPILE, USE HINT('DISALLOW_BATCH_MODE'));
GO

-- now let's see standard behaviour with 2019
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 150;
GO

-- execute and look at execution plan
SELECT [Tax Rate],
	[Lineage Key],
	[Salesperson Key],
	SUM([Quantity]) AS SUM_QTY,
	SUM([Unit Price]) AS SUM_BASE_PRICE,
	COUNT(*) AS COUNT_ORDER
FROM [Fact].[OrderHistoryExtended]
WHERE [Order Date Key] <= DATEADD(dd, -73, '2015-11-13')
GROUP BY [Tax Rate],
	[Lineage Key],
	[Salesperson Key]
ORDER BY [Tax Rate],
	[Lineage Key],
	[Salesperson Key]
GO
-- execute it a second time to see memory grant feedback


------------------------------------------------------------------------
-- Table Variable Deferred Compilation
--
-- Credits
-- https://github.com/microsoft/sql-server-samples/blob/master/samples/features/intelligent-query-processing/IQP%20Demo%20-%20TVDC.sql
------------------------------------------------------------------------
USE WideWorldImportersDW;
GO

-- let's see standard behaviour before 2019
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 140;
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

-- execute and look at execution plan
DECLARE @Order TABLE 
	([Order Key] BIGINT NOT NULL,
	 [Quantity] INT NOT NULL
	);

INSERT @Order
SELECT [Order Key], [Quantity]
FROM [Fact].[OrderHistory]
WHERE  [Quantity] > 99;

-- Look at estimated rows, speed, join algorithm
SELECT oh.[Order Key], oh.[Order Date Key],
   oh.[Unit Price], o.Quantity
FROM Fact.OrderHistoryExtended AS oh
INNER JOIN @Order AS o
	ON o.[Order Key] = oh.[Order Key]
WHERE oh.[Unit Price] > 0.10
ORDER BY oh.[Unit Price] DESC;
GO

-- now let's see standard behaviour with 2019
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 150;
GO

-- execute it again and look at execution plan
DECLARE @Order TABLE 
	([Order Key] BIGINT NOT NULL,
	 [Quantity] INT NOT NULL
	);

INSERT @Order
SELECT [Order Key], [Quantity]
FROM [Fact].[OrderHistory]
WHERE  [Quantity] > 99;

-- Look at estimated rows, speed, join algorithm
SELECT oh.[Order Key], oh.[Order Date Key],
   oh.[Unit Price], o.Quantity
FROM Fact.OrderHistoryExtended AS oh
INNER JOIN @Order AS o
	ON o.[Order Key] = oh.[Order Key]
WHERE oh.[Unit Price] > 0.10
ORDER BY oh.[Unit Price] DESC;
GO

------------------------------------------------------------------------
-- Scalar UDF AUtomatic In-Lining
--
-- Credits
-- https://github.com/microsoft/sql-server-samples/blob/master/samples/features/intelligent-query-processing/IQP%20Demo%20-%20Scalar%20UDF%20Inlining.sql
------------------------------------------------------------------------
USE WideWorldImportersDW;
GO

-- let's see standard behaviour before 2019
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 140;
GO

-- create the UDF
CREATE OR ALTER FUNCTION 
	dbo.ufn_customer_category(@CustomerKey INT) 
RETURNS CHAR(10) AS
BEGIN
	DECLARE @total_amount DECIMAL(18,2);
	DECLARE @category CHAR(10);

	SELECT @total_amount = SUM([Total Including Tax]) 
	FROM [Fact].[OrderHistory]
	WHERE [Customer Key] = @CustomerKey;

	IF @total_amount < 500000
		SET @category = 'REGULAR';
	ELSE IF @total_amount < 1000000
		SET @category = 'GOLD';
	ELSE 
		SET @category = 'PLATINUM';

	RETURN @category;
END
GO

-- check to see if it's in-lineable (columns is_inlineable, inline_type)
SELECT	*
FROM	sys.sql_modules
WHERE	[object_id] = OBJECT_ID('ufn_customer_category')
GO

-- execute and look at execution plan
SELECT TOP 100
		[Customer Key], [Customer],
       dbo.ufn_customer_category([Customer Key]) AS [Discount Price]
FROM [Dimension].[Customer]
ORDER BY [Customer Key]
--OPTION (RECOMPILE,USE HINT('DISABLE_TSQL_SCALAR_UDF_INLINING'));
GO

-- now let's see standard behaviour with 2019
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 150;
GO

-- execute again and look at execution plan
SELECT TOP 100
		[Customer Key], [Customer],
       dbo.ufn_customer_category([Customer Key]) AS [Discount Price]
FROM [Dimension].[Customer]
ORDER BY [Customer Key];
GO

------------------------------------------------------------------------
-- Approximate Distinct Count 
--
-- Credits
------------------------------------------------------------------------
USE WideWorldImportersDW;
GO

-- we need to set compatibility level to 2019
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 150;
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

-- activate statistics
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- execute and look at execution plan
-- Note: time slightly less, I/O same, memory way less
SELECT COUNT(DISTINCT [WWI Order ID])
FROM [Fact].[OrderHistoryExtended]
OPTION (USE HINT('DISALLOW_BATCH_MODE'), RECOMPILE); -- Isolating out BMOR
GO
SELECT APPROX_COUNT_DISTINCT([WWI Order ID])
FROM [Fact].[OrderHistoryExtended]
OPTION (USE HINT('DISALLOW_BATCH_MODE'), RECOMPILE); -- Isolating out BMOR
GO

-- execute and look at execution plan without Isolating out BMOR
-- Note: time slightly less, I/O same, memory still much less
SELECT COUNT(DISTINCT [WWI Order ID])
FROM [Fact].[OrderHistoryExtended]
OPTION (RECOMPILE);
GO
SELECT APPROX_COUNT_DISTINCT([WWI Order ID])
FROM [Fact].[OrderHistoryExtended]
OPTION (RECOMPILE);
GO

-- turn off statistics
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

