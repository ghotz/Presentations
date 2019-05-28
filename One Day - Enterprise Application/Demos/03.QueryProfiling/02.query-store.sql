------------------------------------------------------------------------
-- Copyright:   2018 Gianluca Hotz
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
-- Credits:     Demos on https://docs.microsoft.com
------------------------------------------------------------------------

USE WideWorldImporters;
GO

------------------------------------------------------------------------
-- Prepare demo
------------------------------------------------------------------------
-- make sure supporting index is created
DROP INDEX IF EXISTS [NCCX_Sales_OrderLines] ON [Sales].[OrderLines]
CREATE NONCLUSTERED COLUMNSTORE INDEX [NCCX_Sales_OrderLines] ON [Sales].[OrderLines]
(
	[OrderID],
	[StockItemID],
	[Description],
	[Quantity],
	[UnitPrice],
	[PickedQuantity],
	[PackageTypeID] -- adding package type id for demo purpose
)WITH (DROP_EXISTING = OFF, COMPRESSION_DELAY = 0) 
GO

-- Insert one OrderLine that with PackageTypeID=(0) will cause regression
DELETE	Sales.OrderLines WHERE PackageTypeID = 0;
DELETE	Warehouse.PackageTypes WHERE PackageTypeID = 0;
INSERT	Warehouse.PackageTypes (PackageTypeID, PackageTypeName, LastEditedBy)
VALUES	(0, 'FLGP', 1);
INSERT	Sales.OrderLines (OrderId, StockItemID, [Description], PAckageTypeID, quantity, unitprice, taxrate, PickedQuantity,LastEditedBy)
SELECT TOP 1 OrderID, StockItemID, [Description], PackageTypeID = 0, Quantity, UnitPrice, taxrate , PickedQuantity,LastEditedBy
FROM	Sales.OrderLines;
UPDATE STATISTICS Sales.OrderLines WITH FULLSCAN;
UPDATE STATISTICS Warehouse.PackageTypes;
GO

-- Execute the query and include "Actual execution plan" in SSMS and show the plan - it should have Hash Match (Aggregate) operator with Columnstore Index Scan
EXEC	sp_executesql N'select avg([UnitPrice]*[Quantity]) from Sales.OrderLines where PackageTypeID = @packagetypeid', N'@packagetypeid int'
		, @packagetypeid = 7;
GO 100	-- increase as nedded if laptop very fast!

-- 1. Execute this query 45-300 times to setup the baseline.
-- If you have QUERY_STORE CAPTURE_POLICY=AUTO increase number in GO <number> to at least 60

-- 2. Execute the procedure that causes plan regression
-- Optionally, include "Actual execution plan" in SSMS and show the plan - it should have Stream Aggregate, Index Seek & Nested Loops
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO
EXEC	sp_executesql N'select avg([UnitPrice]*[Quantity]) from Sales.OrderLines where PackageTypeID = @packagetypeid', N'@packagetypeid int'
		, @packagetypeid = 0;
GO
EXEC	sp_executesql N'select avg([UnitPrice]*[Quantity]) from Sales.OrderLines where PackageTypeID = @packagetypeid', N'@packagetypeid int'
		, @packagetypeid = 7;
GO 20


------------------------------------------------------------------------
-- Query Store Wait Stats
------------------------------------------------------------------------
USE [AdventureWorks2017];
GO

-- check if Query Store option is active
SELECT wait_stats_capture_mode_desc FROM sys.database_query_store_options;
GO
-- turn it on if not active
ALTER DATABASE AdventureWorks2017 SET QUERY_STORE (WAIT_STATS_CAPTURE_MODE = ON);
GO

-- Start Query Store

DBCC DROPCLEANBUFFERS;
GO
-- run the script 00.adv-queries-2017.sql to simulate a workload

-- Flush Query Store data 
EXEC sp_query_store_flush_db;
GO

-- Check "Top Resource Consuming Queries" dashboard in Query Store selecting
-- Wait Time (ms) as the metric to be analyzed and check the tooltip

-- Query store can also be queried directly
-- remember we are dealing with check wait categories and not types (less granular)
SELECT * FROM sys.query_store_wait_stats;
GO
SELECT	*
FROM	sys.query_store_wait_stats
WHERE	plan_id = 4
ORDER BY
	total_query_wait_time_ms DESC;
GO

-- Cleanup
ALTER DATABASE [AdventureWorks2017] SET QUERY_STORE = OFF;
GO
