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
-- Credits:     Based on official demo
--              https://github.com/Microsoft/sql-server-samples/tree/master/samples/features/automatic-tuning/force-last-good-plan
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Auto Tuning
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

-- Helper procedures
CREATE OR ALTER PROCEDURE [dbo].[report] (@packagetypeid int)
AS BEGIN
	EXEC sp_executesql N'select avg([UnitPrice]*[Quantity]) from Sales.OrderLines where PackageTypeID = @packagetypeid', N'@packagetypeid int', @packagetypeid;
END
GO
CREATE OR ALTER PROCEDURE [dbo].[regression]
AS BEGIN
	ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
	BEGIN
		   declare @packagetypeid int = 0;
		   exec report @packagetypeid;
	END
END
GO

------------------------------------------------------------------------
-- Plan regression identification & manual tuning
------------------------------------------------------------------------
ALTER DATABASE CURRENT SET AUTOMATIC_TUNING (FORCE_LAST_GOOD_PLAN = OFF);
ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 140;
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
ALTER DATABASE CURRENT SET QUERY_STORE CLEAR ALL;
GO

-- NOTE! Activate Query Store

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

-- 4. Find a recommendation that can fix this issue:
SELECT reason, score,
	 script = JSON_VALUE(details, '$.implementationDetails.script')
 FROM sys.dm_db_tuning_recommendations;
 GO

 -- 4.1. Optionally get more detailed information about the regression and recommendation.
SELECT reason, score,
	 script = JSON_VALUE(details, '$.implementationDetails.script'),
	 planForceDetails.[query_id],
	 planForceDetails.[new plan_id],
	 planForceDetails.[recommended plan_id],
	 estimated_gain = (regressedPlanExecutionCount+recommendedPlanExecutionCount)*(regressedPlanCpuTimeAverage-recommendedPlanCpuTimeAverage)/1000000,
	 error_prone = IIF(regressedPlanErrorCount>recommendedPlanErrorCount, 'YES','NO')
 FROM sys.dm_db_tuning_recommendations
     CROSS APPLY OPENJSON (Details, '$.planForceDetails')
                 WITH ( [query_id] int '$.queryId',
                        [new plan_id] int '$.regressedPlanId',
                        [recommended plan_id] int '$.recommendedPlanId',
                        regressedPlanErrorCount int,
                        recommendedPlanErrorCount int,
                        regressedPlanExecutionCount int,
                        regressedPlanCpuTimeAverage float,
                        recommendedPlanExecutionCount int,
                        recommendedPlanCpuTimeAverage float ) as planForceDetails;
-- IMPORTANT NOTE: check is estimated_gain > 10.
-- If estimated_gain < 10 THEN FLGP=ON will not automatically force the plan!!!
-- In that case increase the number of executions in initial workload.
-- Make sure that SQL Engine uses columnstore in original plan and nonclustered index in regressed plan.

-- Note: User can apply script and force the recommended plan to correct the error.
<<Insert T-SQL from the script column here and execute the script>>
-- e.g.: exec sp_query_store_force_plan @query_id = 1, @plan_id = 1

-- 5. Execute the query again - verify that it is faster.
EXEC	sp_executesql N'select avg([UnitPrice]*[Quantity]) from Sales.OrderLines where PackageTypeID = @packagetypeid', N'@packagetypeid int'
		, @packagetypeid = 7;
GO 

-- Optionally, include "Actual execution plan" in SSMS and show the plan - it should have Hash Aggregate & Columnstore again

------------------------------------------------------------------------
-- Plan regression identification & auto tuning (doesn't always work)
------------------------------------------------------------------------
ALTER DATABASE CURRENT SET AUTOMATIC_TUNING (FORCE_LAST_GOOD_PLAN = ON);
ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 140;
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
ALTER DATABASE CURRENT SET QUERY_STORE CLEAR ALL;
GO

-- Execute baseline
EXEC	sp_executesql N'select avg([UnitPrice]*[Quantity]) from Sales.OrderLines where PackageTypeID = @packagetypeid', N'@packagetypeid int'
		, @packagetypeid = 7;
GO 100	-- increase as nedded if laptop very fast!

-- Cause regression
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
EXEC	sp_executesql N'select avg([UnitPrice]*[Quantity]) from Sales.OrderLines where PackageTypeID = @packagetypeid', N'@packagetypeid int'
		, @packagetypeid = 0;
GO
--DBCC DROPCLEANBUFFERS
EXEC	sp_executesql N'select avg([UnitPrice]*[Quantity]) from Sales.OrderLines where PackageTypeID = @packagetypeid', N'@packagetypeid int'
		, @packagetypeid = 7;
GO 20

-- 4. Find a recommendation and check is it in "Verifying" or "Success" state:
SELECT reason, score,
	JSON_VALUE(state, '$.currentValue') state,
	JSON_VALUE(state, '$.reason') state_transition_reason,
    JSON_VALUE(details, '$.implementationDetails.script') script,
    planForceDetails.*
FROM sys.dm_db_tuning_recommendations
  CROSS APPLY OPENJSON (Details, '$.planForceDetails')
    WITH (  [query_id] int '$.queryId',
            [new plan_id] int '$.regressedPlanId',
            [recommended plan_id] int '$.recommendedPlanId'
          ) as planForceDetails;
GO

-- 5. Recommendation is in "Verifying" state, but the last good plan is forced, so the query will be faster:
EXEC	sp_executesql N'select avg([UnitPrice]*[Quantity]) from Sales.OrderLines where PackageTypeID = @packagetypeid', N'@packagetypeid int'
		, @packagetypeid = 7;
GO

-- Open Query Store/"Top Resource Consuming Queries" dialog in SSMS and show that the better plan is forced.
