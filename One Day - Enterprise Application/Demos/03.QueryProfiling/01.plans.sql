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

------------------------------------------------------------------------
-- Execution Plan Enhancements
--
-- Beware of accuracy!
-- https://www.brentozar.com/archive/2017/07/sql-2016-sp1-shows-wait-stats-execution-plans
-- https://blogs.msdn.microsoft.com/sql_server_team/making-parallelism-waits-actionable
------------------------------------------------------------------------
USE AdventureWorks2017;
DBCC DROPCLEANBUFFERS;
GO
-- Old way to profile execution time and I/O
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
EXEC dbo.GetOrder 870;
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

DBCC DROPCLEANBUFFERS;
GO
-- Now we can look at execution plan SELECT operator, new items
-- QueryTimeStats, Trace Flag, Wait Stats, memory grant
EXEC dbo.GetOrder 870;
GO

------------------------------------------------------------------------
-- Query execution profiling
------------------------------------------------------------------------

--
-- Transient in-flight execution plan
-- copy query to other session and run it
--
SET STATISTICS XML ON;
--SET STATISTICS PROFILE ON;
GO
USE [AdventureWorksDW2017];
GO
SELECT DimCustomer.CustomerKey ,
       DimCustomer.GeographyKey ,
       DimGeography.GeographyKey AS Expr1 ,
       DimGeography.StateProvinceCode ,
       DimReseller.ResellerKey ,
       DimReseller.ResellerAlternateKey ,
       DimReseller.Phone
FROM   DimGeography
       INNER JOIN DimReseller ON DimGeography.GeographyKey = DimReseller.GeographyKey
       INNER JOIN DimCustomer ON DimGeography.GeographyKey = DimCustomer.GeographyKey
       CROSS JOIN DimCurrency;
GO

-- copy session id and show plan
SELECT * FROM sys.dm_exec_query_statistics_xml(58);
GO
-- copy session id and show row counters
SELECT	physical_operator_name, node_id, thread_id, row_count, estimate_row_count, *
FROM sys.dm_exec_query_profiles WHERE session_id = 58
GO