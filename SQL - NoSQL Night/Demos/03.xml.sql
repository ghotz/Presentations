------------------------------------------------------------------------
-- Script:		xml.sql
-- Copyright:	2018 Gianluca Hotz
-- License:		MIT License
-- Credits:		http://sqlfascination.com/2010/03/10/locating-table-scans-within-the-query-cache
--				http://www.sqlservercentral.com/blogs/sql-geek/2017/10/07/extracting-deadlock-information-using-system_health-extended-events/
--				http://thesqldude.com/2012/01/31/sql-server-ring-buffers-and-the-fellowship-of-the-ring/
------------------------------------------------------------------------

------------------------------------------------------------------------
-- XML is fully supported and used internally in several areas
------------------------------------------------------------------------

-- For example, display graphical execution plans and check the XML behind
USE AdventureWorks2017;
GO

DBCC FREEPROCCACHE;	-- clar plan cache
GO

SELECT	* 
FROM	Sales.SalesOrderHeader;
GO
SELECT	COUNT(*) AS NumOrders
FROM	Sales.SalesOrderHeader
WHERE	OrderDate BETWEEN '20120101' AND '20121231';
GO

-- XML plans are also in the plan cache
SELECT cp.*, st.*, qp.*
FROM	sys.dm_exec_cached_plans cp
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) st
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp

-- So we can do things like searching for table/index scans
WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan'),
CachedPlans (DatabaseName,SchemaName,ObjectName,PhysicalOperator, LogicalOperator, QueryText,QueryPlan, CacheObjectType, ObjectType)
AS
(
	SELECT
		COALESCE(
			RelOp.op.value(N'TableScan[1]/Object[1]/@Database', N'varchar(50)') , 
			RelOp.op.value(N'OutputList[1]/ColumnReference[1]/@Database', N'varchar(50)') ,
			RelOp.op.value(N'IndexScan[1]/Object[1]/@Database', N'varchar(50)') ,
			'Unknown'
		) AS DatabaseName,
		COALESCE(
			RelOp.op.value(N'TableScan[1]/Object[1]/@Schema', N'varchar(50)') ,
			RelOp.op.value(N'OutputList[1]/ColumnReference[1]/@Schema', N'varchar(50)') ,
			RelOp.op.value(N'IndexScan[1]/Object[1]/@Schema', N'varchar(50)') ,
			'Unknown'
			) as SchemaName,
		COALESCE(
			RelOp.op.value(N'TableScan[1]/Object[1]/@Table', N'varchar(50)') ,
			RelOp.op.value(N'OutputList[1]/ColumnReference[1]/@Table', N'varchar(50)') ,
			RelOp.op.value(N'IndexScan[1]/Object[1]/@Table', N'varchar(50)') ,
			'Unknown'
		) as ObjectName,
		RelOp.op.value(N'@PhysicalOp', N'varchar(50)') as PhysicalOperator,
		RelOp.op.value(N'@LogicalOp', N'varchar(50)') as LogicalOperator,
		st.text as QueryText,
		qp.query_plan as QueryPlan,
		cp.cacheobjtype as CacheObjectType,
		cp.objtype as ObjectType
	FROM
	sys.dm_exec_cached_plans cp
	CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) st
	CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
	CROSS APPLY qp.query_plan.nodes(N'//RelOp') RelOp (op)
)
SELECT
	DatabaseName,SchemaName,ObjectName,PhysicalOperator
	, LogicalOperator, QueryText,CacheObjectType, ObjectType, queryplan
FROM
	CachedPlans
WHERE
	CacheObjectType = N'Compiled Plan'
AND	PhysicalOperator IN ('Clustered Index Scan', 'Table Scan', 'Index Scan')
AND DatabaseName = '[AdventureWorks2017]'
AND SchemaName <> '[sys]'
GO

------------------------------------------------------------------------
-- Another area where XML is used are Extended Events
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Example to get deadlock reports from System Health session
------------------------------------------------------------------------
 SELECT
	XEvent.value('(@timestamp)[1]', 'datetime') as UTC_event_time,
	XEvent.query('(data/value/deadlock)') AS deadlock_graph
FROM
(
	SELECT	CAST(event_data AS XML) as [target_data]
	FROM	sys.fn_xe_file_target_read_file('system_health_*.xel',NULL,NULL,NULL)
	WHERE	[object_name] like 'xml_deadlock_report'
) AS [x]
CROSS APPLY target_data.nodes('/event') AS XEventData(XEvent);
GO

------------------------------------------------------------------------
-- Example to analyze memory pressure from ring buffers
------------------------------------------------------------------------
SELECT
	CONVERT (varchar(30), GETDATE(), 121) AS [RunTime]
,	DATEADD(ms, (rbf.[timestamp] - tme.ms_ticks) % 1000, DATEADD(ss, (rbf.[timestamp] - tme.ms_ticks) / 1000, GETDATE())) AS Time_stamp
,	CAST(record AS xml).value('(//Record/ResourceMonitor/Notification)[1]', 'varchar(30)') AS [Notification_type]
,	CAST(record AS xml).value('(//Record/MemoryRecord/MemoryUtilization)[1]', 'bigint') AS [MemoryUtilization %]
,	CAST(record AS xml).value('(//Record/MemoryNode/@id)[1]', 'bigint') AS [Node Id]
,	CAST(record AS xml).value('(//Record/ResourceMonitor/IndicatorsProcess)[1]', 'int') AS [Process_Indicator]
,	CAST(record AS xml).value('(//Record/ResourceMonitor/IndicatorsSystem)[1]', 'int') AS [System_Indicator]
,	CAST(record AS xml).value('(//Record/MemoryNode/ReservedMemory)[1]', 'bigint') AS [SQL_ReservedMemory_KB]
,	CAST(record AS xml).value('(//Record/MemoryNode/CommittedMemory)[1]', 'bigint') AS [SQL_CommittedMemory_KB]
,	CAST(record AS xml).value('(//Record/MemoryNode/AWEMemory)[1]', 'bigint') AS [SQL_AWEMemory]
,	CAST(record AS xml).value('(//Record/MemoryNode/SinglePagesMemory)[1]', 'bigint') AS [SinglePagesMemory]
,	CAST(record AS xml).value('(//Record/MemoryNode/MultiplePagesMemory)[1]', 'bigint') AS [MultiplePagesMemory]
,	CAST(record AS xml).value('(//Record/MemoryRecord/TotalPhysicalMemory)[1]', 'bigint') AS [TotalPhysicalMemory_KB]
,	CAST(record AS xml).value('(//Record/MemoryRecord/AvailablePhysicalMemory)[1]', 'bigint') AS [AvailablePhysicalMemory_KB]
,	CAST(record AS xml).value('(//Record/MemoryRecord/TotalPageFile)[1]', 'bigint') AS [TotalPageFile_KB]
,	CAST(record AS xml).value('(//Record/MemoryRecord/AvailablePageFile)[1]', 'bigint') AS [AvailablePageFile_KB]
,	CAST(record AS xml).value('(//Record/MemoryRecord/TotalVirtualAddressSpace)[1]', 'bigint') AS [TotalVirtualAddressSpace_KB]
,	CAST(record AS xml).value('(//Record/MemoryRecord/AvailableVirtualAddressSpace)[1]', 'bigint') AS [AvailableVirtualAddressSpace_KB]
--,	CAST(record AS xml).value('(//Record/@id)[1]', 'bigint') AS [Record Id]
--,	CAST(record AS xml).value('(//Record/@type)[1]', 'varchar(30)') AS [Type]
--,	CAST(record AS xml).value('(//Record/@time)[1]', 'bigint') AS [Record Time]
--,	tme.ms_ticks AS [Current Time]
,	CAST(record AS xml) AS full_event
FROM	sys.dm_os_ring_buffers rbf
CROSS
JOIN	sys.dm_os_sys_info tme
WHERE
    rbf.ring_buffer_type = 'RING_BUFFER_RESOURCE_MONITOR'
--AND CAST(record as xml).value('(//Record/ResourceMonitor/Notification)[1]', 'varchar(30)') = 'RESOURCE_MEMPHYSICAL_LOW'
ORDER BY
	rbf.[timestamp] ASC;
GO
