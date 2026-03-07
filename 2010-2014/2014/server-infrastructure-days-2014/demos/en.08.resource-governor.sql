------------------------------------------------------------------------
--	Script:			en.08.resource-governor
--	Description:	SQL Server 2014 Resource Governor
--	Author:			Gianluca Hotz (SolidQ)
--	Copyright:		Attribution-NonCommercial-ShareAlike 3.0
------------------------------------------------------------------------

USE AdventureWorks2012;
GO

--	Add to performance monitor these SQL counters
--	Resource Poll Stats\Disk Read IO Throttled/sec
--	Resource Poll Stats\Disk Read IO/sec


--	Run the following workload in another connection
--	Empties cache and run a table scan
--	On my laptop runs around 100-150 IOPS
DBCC DROPCLEANBUFFERS;
SELECT COUNT(*) FROM Sales.SalesOrderDetail;
GO 10000

--	Change the default resource pool
ALTER RESOURCE POOL [default]
WITH (MAX_IOPS_PER_VOLUME = 50);
GO

--	Reconfigure and start using governor
ALTER RESOURCE GOVERNOR RECONFIGURE;
GO

--	Reset to unlimited threshold
ALTER RESOURCE POOL [default]
WITH (MAX_IOPS_PER_VOLUME = 0);
GO

--	Disable resource governor
ALTER RESOURCE GOVERNOR DISABLE;
GO