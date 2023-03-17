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
-- Demo: Batch Execution mode
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
