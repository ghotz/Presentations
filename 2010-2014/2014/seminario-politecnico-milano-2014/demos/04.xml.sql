------------------------------------------------------------------------
-- Script:			04.xml.sql
-- Last update:		2012-01-20
-- Author:			Gianluca Hotz  (SolidQ)
-- Credits:			http://sqlfascination.com/2010/03/10/locating-table-scans-within-the-query-cache
-- Copyright:		Attribution-NonCommercial-ShareAlike 3.0
-- Versions:		SQL2012
--
-- Description:		Demo SSMS environment
------------------------------------------------------------------------

-- XML is fully supported and used internally in several areas

-- For example, display graphical execution plans and check the XML behind
DBCC FREEPROCCACHE;	-- clar plan cache
GO

SELECT	* 
FROM	TSQL2012.Sales.Orders;

SELECT	COUNT(*) AS NumOrders
FROM	TSQL2012.Sales.Orders
WHERE	orderdate BETWEEN '20080101' AND '20080131';
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
AND DatabaseName = '[TSQL2012]'
AND SchemaName <> '[sys]'
