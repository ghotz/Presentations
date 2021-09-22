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
-- Credits:    https://github.com/microsoft/bobsql/blob/master/demos/sqlserver/polybase
------------------------------------------------------------------------

------------------------------------------------------------------------
-- This demo relay on database Integration created in the previous
-- demo script pb.02.fundamental.en.sql
------------------------------------------------------------------------

------------------------------------------------------------------------
-- PolyBase Scale Out Metadata
------------------------------------------------------------------------
-- List out the nodes in the scale out group
SELECT * FROM sys.dm_exec_compute_nodes;
GO

-- Get more details about the status of the nodes
SELECT * FROM sys.dm_exec_compute_node_status;
GO

-- Get information about DMS services
SELECT	* 
FROM	sys.dm_exec_dms_services;
GO

-- List out detailed errors from the nodes
SELECT	*
FROM	sys.dm_exec_compute_node_errors
ORDER BY
	create_time DESC;
GO

------------------------------------------------------------------------
-- Execute a simple query
------------------------------------------------------------------------
USE Integration;
GO

SELECT	SalesOrderID, OrderDate, CustomerID
FROM	Sales.SalesOrderHeader
WHERE	YEAR(OrderDate) = 2004;
GO

------------------------------------------------------------------------
-- Discover how execution was carried out (last 1000 requests)
------------------------------------------------------------------------

-- Find out queries against external tables
SELECT	DR.execution_id, ST.*, DR.*
FROM	sys.dm_exec_distributed_requests AS DR
CROSS
APPLY	sys.dm_exec_sql_text(DR.sql_handle) AS ST
WHERE	ST.[text] LIKE '%SalesOrderHeader%'
ORDER BY DR.end_time DESC;
GO

-- Find your execution_id and use this for the next query
-- total_elapsed_time in ms
SELECT	*
FROM	sys.dm_exec_distributed_request_steps
WHERE	execution_id = 'QID3606'
ORDER BY step_index;
GO

-- Get more details on each step
SELECT	*
FROM	sys.dm_exec_distributed_sql_requests
WHERE	execution_id = 'QID3606'
ORDER BY step_index, compute_node_id, distribution_id;
GO

-- Get more details from the compute nodes
SELECT	* 
FROM	sys.dm_exec_dms_workers 
WHERE	execution_id = 'QID3606'
ORDER BY step_index, dms_step_index, compute_node_id, distribution_id
GO

-- Look more at external operations
SELECT	* 
FROM	sys.dm_exec_external_work
WHERE	execution_id = 'QID3606'
GO

------------------------------------------------------------------------
-- Now, create a scale-out group
-- 
-- Use sys.sp_polybase_join_group to add compute nodes to
-- PSQLMASTER.alphasys.local that will be the head node
-- pb.03.scale-out-enable.en.ps1 will also restart services
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Check again PolyBase Scale Out Metadata
------------------------------------------------------------------------
-- List out the nodes in the scale out group
SELECT * FROM sys.dm_exec_compute_nodes;
GO

-- Get more details about the status of the nodes
SELECT * FROM sys.dm_exec_compute_node_status;
GO

-- Get information about DMS services
SELECT	* 
FROM	sys.dm_exec_dms_services
ORDER BY
		dms_core_id;
GO

------------------------------------------------------------------------
-- Execute again the simple query
------------------------------------------------------------------------
SELECT	*
FROM	Sales.SalesOrderHeader
WHERE	YEAR(OrderDate) = 2004;
GO

------------------------------------------------------------------------
-- Discover how execution was carried out (last 1000 requests)
------------------------------------------------------------------------
-- find the new execution
SELECT	DR.execution_id, ST.*, DR.*
FROM	sys.dm_exec_distributed_requests AS DR
CROSS
APPLY	sys.dm_exec_sql_text(DR.sql_handle) AS ST
WHERE	ST.[text] LIKE '%SalesOrderHeader%'
ORDER BY DR.end_time DESC;
GO

-- Find your execution_id and use this for the next query
SELECT	*
FROM	sys.dm_exec_distributed_request_steps
WHERE	execution_id = 'QID3606'
ORDER BY step_index;
GO
SELECT	*
FROM	sys.dm_exec_distributed_request_steps
WHERE	execution_id = 'QID3641'
ORDER BY step_index;
GO
-- the kind of distributed plan is the same

-- Get more details on each step
SELECT	*
FROM	sys.dm_exec_distributed_sql_requests
WHERE	execution_id = 'QID3606'
ORDER BY step_index, compute_node_id, distribution_id;
GO
SELECT	*
FROM	sys.dm_exec_distributed_sql_requests
WHERE	execution_id = 'QID3641'
ORDER BY step_index, compute_node_id, distribution_id;
GO

-- Get more details from the compute nodes
SELECT	* 
FROM	sys.dm_exec_dms_workers 
WHERE	execution_id = 'QID3606'
ORDER BY step_index, dms_step_index, compute_node_id, distribution_id
GO
SELECT	* 
FROM	sys.dm_exec_dms_workers 
WHERE	execution_id = 'QID3641'
ORDER BY step_index, dms_step_index, compute_node_id, distribution_id
GO

-- Look more at external operations
SELECT	* 
FROM	sys.dm_exec_external_work
WHERE	execution_id = 'QID3606'
GO
SELECT	* 
FROM	sys.dm_exec_external_work
WHERE	execution_id = 'QID3641'
GO

------------------------------------------------------------------------
-- Joining Tables, example 1
------------------------------------------------------------------------
-- predicate on join column
SELECT	O1.SalesOrderID, O1.OrderDate, O1.SalesOrderNumber
,		C1.CustomerID, C1.AccountNumber
FROM	Sales.SalesOrderHeader AS O1
JOIN	Sales.Customer AS C1
  ON	O1.CustomerID = C1.CustomerID
WHERE	C1.CustomerID = 11211;
GO

-- Find out queries against external tables
SELECT	DR.execution_id, ST.*, DR.*
FROM	sys.dm_exec_distributed_requests AS DR
CROSS
APPLY	sys.dm_exec_sql_text(DR.sql_handle) AS ST
WHERE	ST.[text] LIKE '%SalesOrderHeader%'
ORDER BY DR.end_time DESC;
GO

-- Find your execution_id and use this for the next queries
SELECT * FROM sys.dm_exec_distributed_request_steps	WHERE execution_id = 'QID2938' ORDER BY step_index;
SELECT * FROM sys.dm_exec_distributed_sql_requests	WHERE execution_id = 'QID2938' ORDER BY step_index, compute_node_id, distribution_id;
SELECT * FROM sys.dm_exec_dms_workers				WHERE execution_id = 'QID2938' ORDER BY step_index, dms_step_index, compute_node_id, distribution_id;
SELECT * FROM sys.dm_exec_external_work				WHERE execution_id = 'QID2938';
GO
SELECT * FROM sys.dm_exec_distributed_request_steps	WHERE execution_id = 'QID2939' ORDER BY step_index;
SELECT * FROM sys.dm_exec_distributed_sql_requests	WHERE execution_id = 'QID2939' ORDER BY step_index, compute_node_id, distribution_id;
SELECT * FROM sys.dm_exec_dms_workers				WHERE execution_id = 'QID2939' ORDER BY step_index, dms_step_index, compute_node_id, distribution_id;
SELECT * FROM sys.dm_exec_external_work				WHERE execution_id = 'QID2939';
GO

------------------------------------------------------------------------
-- Joining Tables, example 2
------------------------------------------------------------------------
-- predicate on other column
SELECT	O1.SalesOrderID, O1.OrderDate, O1.SalesOrderNumber
,		C1.CustomerID, C1.AccountNumber
FROM	Sales.SalesOrderHeader AS O1
JOIN	Sales.Customer AS C1
  ON	O1.CustomerID = C1.CustomerID
WHERE	O1.OrderDate = '2004-05-01';
GO

-- Find out queries against external tables
SELECT	DR.execution_id, ST.*, DR.*
FROM	sys.dm_exec_distributed_requests AS DR
CROSS
APPLY	sys.dm_exec_sql_text(DR.sql_handle) AS ST
WHERE	ST.[text] LIKE '%SalesOrderHeader%'
ORDER BY DR.end_time DESC;
GO

SELECT * FROM sys.dm_exec_distributed_request_steps	WHERE execution_id = 'QID735' ORDER BY step_index;
SELECT * FROM sys.dm_exec_distributed_sql_requests	WHERE execution_id = 'QID735' ORDER BY step_index, compute_node_id, distribution_id;
SELECT * FROM sys.dm_exec_dms_workers				WHERE execution_id = 'QID735' ORDER BY step_index, dms_step_index, compute_node_id, distribution_id;
SELECT * FROM sys.dm_exec_external_work				WHERE execution_id = 'QID735';
GO
SELECT * FROM sys.dm_exec_distributed_request_steps	WHERE execution_id = 'QID736' ORDER BY step_index;
SELECT * FROM sys.dm_exec_distributed_sql_requests	WHERE execution_id = 'QID736' ORDER BY step_index, compute_node_id, distribution_id;
SELECT * FROM sys.dm_exec_dms_workers				WHERE execution_id = 'QID736' ORDER BY step_index, dms_step_index, compute_node_id, distribution_id;
SELECT * FROM sys.dm_exec_external_work				WHERE execution_id = 'QID736';
GO