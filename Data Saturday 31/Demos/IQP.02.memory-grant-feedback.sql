------------------------------------------------------------------------
-- Copyright:   2022 Gianluca Hotz
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
-- Credits:     Joe Sack https://blogs.msdn.microsoft.com/sqlserverstorageengine/2018/09/24/introducing-batch-mode-on-rowstore
--                       https://github.com/joesackmsft/Conferences/tree/master/IQPDemos
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Demo: Batch mode memory grant feedback
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

-- disable and clear Query Store in 2022 (to avoid persistence)
ALTER DATABASE [WideWorldImportersDW] SET QUERY_STORE CLEAR;
ALTER DATABASE [WideWorldImportersDW] SET QUERY_STORE = OFF;
GO

-- let's see standard behaviour before 2017
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 130;
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

-- first xecution, include execution plan and check the tip in the
-- SELECT operator and MemoryGrantInfo in properties after several
-- execution
EXEC [FactOrderByLineageKey] 1;
GO 2


-- clear procedure cache and change compatibility level (by default memory grant feedback is on)
ALTER DATABASE [WideWorldImportersDW] SET COMPATIBILITY_LEVEL = 140;
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

-- afetr first execution the plan is the same as before
-- but on second execution the tip disappears and MemoryGrantInfo
-- now shows much less memory granted and used
EXEC [FactOrderByLineageKey] 1;
GO 2

-- let's clear again the cache and see what happens when a new 
-- execution requires more memory after feedback lowered it
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO
EXEC [FactOrderByLineageKey] 1;
GO 2
EXEC [FactOrderByLineageKey] 9;
GO 2


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
-- Demo: Row mode memory grant feedback
------------------------------------------------------------------------
USE WideWorldImporters;
GO

-- disable and clear Query Store in 2022 (to avoid persistence)
ALTER DATABASE [WideWorldImportersDW] SET QUERY_STORE CLEAR;
ALTER DATABASE [WideWorldImportersDW] SET QUERY_STORE = OFF;
GO

-- let's see standard behaviour before 2019
ALTER DATABASE WideWorldImporters SET COMPATIBILITY_LEVEL = 140;
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

-- Run query several times and look at execution plan
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
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
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
-- Demo: Memory grant feedback Percentile and Persistence
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

-- disable and clear Query Store in 2022 (to avoid persistence)
ALTER DATABASE [WideWorldImportersDW] SET QUERY_STORE CLEAR;
ALTER DATABASE [WideWorldImportersDW] SET QUERY_STORE = OFF;
GO

-- clear procedure cache and change compatibility level (by default memory grant feedback is on)
ALTER DATABASE [WideWorldImportersDW] SET COMPATIBILITY_LEVEL = 140;
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

-- let's clear again the cache and see what happens when a new 
-- execution requires more memory after feedback lowered it
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO
EXEC [FactOrderByLineageKey] 1;
EXEC [FactOrderByLineageKey] 9;
GO 10

-- The functionality can be disabled independently from the compatibility level
-- at database level:
-- ALTER DATABASE SCOPED CONFIGURATION SET MEMORY_GRANT_FEEDBACK_PERCENTILE = ON|OFF

-- Another problem is that if we clear the procedure cache (e.g. restart)
-- we loose feedback information and have to go through it again
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
EXEC [FactOrderByLineageKey] 1;
EXEC [FactOrderByLineageKey] 1;
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
EXEC [FactOrderByLineageKey] 1;
GO

-- we can enable Query Store persistence in 2002
ALTER DATABASE [WideWorldImportersDW] SET QUERY_STORE CLEAR;
ALTER DATABASE [WideWorldImportersDW] SET QUERY_STORE = ON;
ALTER DATABASE [WideWorldImportersDW] SET QUERY_STORE (OPERATION_MODE = READ_WRITE);
GO

-- now the feedback information survived clearing the cache
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
EXEC [FactOrderByLineageKey] 1;
EXEC [FactOrderByLineageKey] 1;
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
EXEC [FactOrderByLineageKey] 1;
GO

-- Information about memory feedback from Query Store
SELECT
	qpf.feature_desc, qpf.feedback_data, qpf.state_desc
,	qt.query_sql_text
,	(qrs.last_query_max_used_memory * 8192)/1024 as last_query_memory_kb
FROM sys.query_store_plan_feedback qpf
JOIN sys.query_store_plan qp
ON qpf.plan_id = qp.plan_id
JOIN sys.query_store_query qq
ON qp.query_id = qq.query_id
JOIN sys.query_store_query_text qt
ON qq.query_text_id = qt.query_text_id
JOIN sys.query_store_runtime_stats qrs
ON qp.plan_id = qrs.plan_id;
GO
