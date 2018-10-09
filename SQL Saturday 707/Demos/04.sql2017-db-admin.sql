------------------------------------------------------------------------
-- Script:		sql2017-db-admin.sql
-- Copyright:	2017 Gianluca Hotz
-- License:		MIT License
-- Credits:
------------------------------------------------------------------------

------------------------------------------------------------------------
-- System Metadata
------------------------------------------------------------------------

--
-- Extended system information DMV
-- Added socket_count, cores_per_socket, numa_node_count columns for VM sizing
--
SELECT * FROM sys.dm_os_sys_info;
GO

--
-- New Host information DMV on Windows/Linux
--
SELECT * FROM sys.dm_os_host_info;
GO

--
-- Undocumented DMV/DMF as partial replacement for some xp_ procedures
--
SELECT * FROM sys.dm_os_enumerate_fixed_drives;
SELECT * FROM sys.dm_os_enumerate_filesystem('C:\SQLServer\MSSQL14.MSSQLSERVER\MSSQL\Backup', '*.bak');
SELECT * FROM sys.dm_os_file_exists('C:\SQLServer\MSSQL14.MSSQLSERVER\MSSQL\Log');
SELECT * FROM sys.dm_os_file_exists('C:\SQLServer\MSSQL14.MSSQLSERVER\MSSQL\Log\ERRORLOG');
GO


------------------------------------------------------------------------
-- Database Metadata
------------------------------------------------------------------------

--
-- Log file information, many information historically exposed
-- only in undocumented DBCC LOGINFO command
--
SELECT * FROM sys.dm_db_log_stats(db_id('tempdb'));
SELECT * FROM sys.dm_db_log_stats(db_id('Adventureworks2017'));
GO

--
-- Extended file space usage DMV
-- Added modified_extent_page_count to track modified pages
-- allowing smart backup solutions e.g. backup diff if < 70-80%, full otherwise
--
USE [AdventureWorks2017];
GO
-- Perform FULL backup to reset modified_extent_page_count
BACKUP DATABASE [AdventureWorks2017] TO DISK = 'NUL';
GO
-- check modified_extent_page_count
SELECT * FROM sys.dm_db_file_space_usage;
GO
-- update record
UPDATE	Person.Person SET Title = N'Mr'
WHERE	BusinessEntityID = 1;
UPDATE	Person.Person SET Title = NULL
WHERE	BusinessEntityID = 1;
GO
-- check modified_extent_page_count
SELECT * FROM sys.dm_db_file_space_usage;
GO

--
-- Added version store usage information DMV
--
SELECT 
	DB_NAME(database_id) as 'Database Name'
,	reserved_page_count
,	reserved_space_kb 
FROM sys.dm_tran_version_store_space_usage; 
GO

--
-- Histogram information
-- SELECT * FROM sys.stats WHERE object_id = OBJECT_ID('Person.Person')
--
USE [AdventureWorks2017];
GO
SELECT * FROM sys.dm_db_stats_properties(OBJECT_ID('Person.Person'), 2);	-- from sql server 2008
SELECT * FROM sys.dm_db_stats_histogram(OBJECT_ID('Person.Person'), 2);		-- from sql server 2016 SP1 CU2
GO
	
-- Density?
DBCC SHOW_STATISTICS ('Person.Person', 'IX_Person_LastName_FirstName_MiddleName');
GO


------------------------------------------------------------------------
-- DBCC CLONEDATABASE
------------------------------------------------------------------------
USE master;
GO
IF EXISTS (SELECT * FROM sys.databases WHERE [name] = 'AdventureWorks2017_Copy') DROP DATABASE AdventureWorks2017_Copy;
GO

-- clone all: schema, statistics and query store
DBCC CLONEDATABASE('AdventureWorks2017', 'AdventureWorks2017_Copy');
GO

-- Metadata to check if database is a clone
SELECT DATABASEPROPERTYEX('AdventureWorks2017_Copy','isClone');
GO

-- files re-created with unique physical names
SELECT * FROM AdventureWorks2017.sys.database_files;
SELECT * FROM AdventureWorks2017_Copy.sys.database_files;
GO

DROP DATABASE AdventureWorks2017_Copy;
GO

------------------------------------------------------------------------
-- USE HINT Query Option
------------------------------------------------------------------------
USE AdventureWorks2017;
GO

-- create stored procedure
CREATE OR ALTER PROCEDURE dbo.GetOrder
	@ProductID int
AS
BEGIN 
	SELECT SalesOrderDetailID, OrderQty
	FROM Sales.SalesOrderDetail
	WHERE ProductID = @ProductID;
END
GO

-- include execution plan
-- product ID 870 has many detail order row so the plan is compiled to scan
EXEC dbo.GetOrder 870;
-- however the plan is not optimal for product ID 897 that returns only 2 rows
-- show estimated vs actual in execution plan
EXEC dbo.GetOrder 897;
GO

-- we can use new USE HINT to disable parameter sniffing
-- (although in this case OPTION(RECOMPILE) would probably be a better choice
CREATE OR ALTER PROCEDURE dbo.GetOrder
	@ProductID int
AS
BEGIN 
	SELECT SalesOrderDetailID, OrderQty
	FROM Sales.SalesOrderDetail
	WHERE ProductID = @ProductID
	OPTION (USE HINT('DISABLE_PARAMETER_SNIFFING')); -- instead of OPTION (QUERYTRACEON 4136);
END
GO
 
-- list of valid hints but no trace flag info :-(
SELECT * FROM sys.dm_exec_valid_use_hints;
GO

------------------------------------------------------------------------
-- Execution Plan Enhancements
------------------------------------------------------------------------
USE AdventureWorks2017;
DBCC DROPCLEANBUFFERS;
GO

-- look at execution plan SELECT operator new items
-- QueryTimeStats, Trace Flag, Wait Stats
EXEC dbo.GetOrder 870;
GO

-- we can also look at Wait Stats per session
-- (reset when session opened or reset by connection pooling) 
SELECT	*
FROM	sys.dm_exec_session_wait_stats
WHERE	session_id = @@SPID;
GO

--USE [AdventureWorksDW2017];
--GO
--SELECT DimCustomer.CustomerKey ,
--       DimCustomer.GeographyKey ,
--       DimGeography.GeographyKey AS Expr1 ,
--       DimGeography.StateProvinceCode ,
--       DimReseller.ResellerKey ,
--       DimReseller.ResellerAlternateKey ,
--       DimReseller.Phone
--FROM   DimGeography
--       INNER JOIN DimReseller ON DimGeography.GeographyKey = DimReseller.GeographyKey
--       INNER JOIN DimCustomer ON DimGeography.GeographyKey = DimCustomer.GeographyKey
--       CROSS JOIN DimCurrency;
--GO

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
SELECT * FROM sys.dm_exec_query_statistics_xml(60);
GO
-- copy session id and show row counters
SELECT	physical_operator_name, node_id, thread_id, row_count, estimate_row_count, *
FROM sys.dm_exec_query_profiles WHERE session_id = 60;
GO

-- at the end of query execution note the difference between the number of actual
-- rows between the captured execution plan and the final plan

------------------------------------------------------------------------
-- Query Store Wait Stats
------------------------------------------------------------------------
USE [AdventureWorksDW2017];
GO

-- check if Query Store option is active
SELECT wait_stats_capture_mode_desc FROM sys.database_query_store_options;
GO
-- turn it on if not active
ALTER DATABASE AdventureWorksDW2017 SET QUERY_STORE (WAIT_STATS_CAPTURE_MODE = ON);
GO

-- run the query
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

-- Check "Top Resource Consuming Queries" dashboard in Query Store selecting
-- Wait Time (ms) as the metric to be analyzed and check the tooltip

-- Query store can also be queried directly
-- remember we are dealing with check wait categories and not types (less granular)
SELECT * FROM sys.query_store_wait_stats;
GO

