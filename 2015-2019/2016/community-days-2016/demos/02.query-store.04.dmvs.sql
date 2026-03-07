------------------------------------------------------------------------
--	Description:	Query store demo dmvs
------------------------------------------------------------------------
-- Credits original script:
-- AdventureWorks2016CTP3 samples: Query Store
----------------------------------------------------------------

/*
	This demo uses data that Query Store collects in AdventureWorks2016CTP3	
	This script includes query examples for the following scenarios:
	1) examining the state of Query Store
	2) Analyze collected data
	3) Clear Query Store data (optionally)

	For more details on Query Store visit:
		MSDN page: https://msdn.microsoft.com/en-us/library/dn817826.aspx 
		Azure Blogs: https://azure.microsoft.com/en-us/blog/query-store-a-flight-data-recorder-for-your-database/ 
*/

USE [QueryStore];
GO

----------------------------------------------------------------
-- PART 1: Review the state of the Query Store
----------------------------------------------------------------
/* 	This query returns the most important Query Store parameters*/
SELECT actual_state_desc, desired_state_desc, current_storage_size_mb, max_storage_size_mb, readonly_reason,
stale_query_threshold_days, size_based_cleanup_mode_desc, query_capture_mode_desc 
FROM sys.database_query_store_options;

--USE master;
--GO

--/*If actual_state is OFF, turn on Query Store again*/
--ALTER DATABASE 
--[QueryStore] 
--SET QUERY_STORE = ON
--(	
--	CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 31), 
--	DATA_FLUSH_INTERVAL_SECONDS = 900, 
--	INTERVAL_LENGTH_MINUTES = 5, 
--	MAX_STORAGE_SIZE_MB = 1024, 
--	QUERY_CAPTURE_MODE = ALL, 
--	SIZE_BASED_CLEANUP_MODE = AUTO
--)
--GO

--/*If actual_state is READ_ONLY check if current_storage_size exceeded max_storage_size_mb and perform these steps*/
--ALTER DATABASE [QueryStore] 
--SET QUERY_STORE (SIZE_BASED_CLEANUP_MODE = AUTO)

--/*Switch Query Store to READ_WRITE mode again*/
--ALTER DATABASE [QueryStore] 
--SET QUERY_STORE (OPERATION_MODE = READ_WRITE);
--GO


 ----------------------------------------------------------------
-- PART 2: Analyze Query Store data
-----------------------------------------------------------------
USE [QueryStore];
GO

/*Find last 10 queries executed in the database*/
SELECT TOP 10 qt.query_sql_text, q.query_id, 
    qt.query_text_id, p.plan_id, rs.last_execution_time
FROM sys.query_store_query_text AS qt 
JOIN sys.query_store_query AS q 
    ON qt.query_text_id = q.query_text_id 
JOIN sys.query_store_plan AS p 
    ON q.query_id = p.query_id 
JOIN sys.query_store_runtime_stats AS rs 
    ON p.plan_id = rs.plan_id
ORDER BY rs.last_execution_time DESC;

/*Get number of executions for each query*/
SELECT q.query_id, qt.query_text_id, qt.query_sql_text, 
    SUM(rs.count_executions) AS total_execution_count
FROM sys.query_store_query_text AS qt 
JOIN sys.query_store_query AS q 
    ON qt.query_text_id = q.query_text_id 
JOIN sys.query_store_plan AS p 
    ON q.query_id = p.query_id 
JOIN sys.query_store_runtime_stats AS rs 
    ON p.plan_id = rs.plan_id
GROUP BY q.query_id, qt.query_text_id, qt.query_sql_text
ORDER BY total_execution_count DESC;

GO

/*Get queries with more than one execution plan (plan forcing candidates)*/
;WITH Query_MultPlans
AS
(
SELECT COUNT(*) AS cnt, q.query_id 
FROM sys.query_store_query_text AS qt
JOIN sys.query_store_query AS q
    ON qt.query_text_id = q.query_text_id
JOIN sys.query_store_plan AS p
    ON p.query_id = q.query_id
GROUP BY q.query_id
HAVING COUNT(distinct plan_id) > 1
)

SELECT q.query_id, object_name(object_id) AS ContainingObject, query_sql_text,
plan_id, CAST(p.query_plan as xml) AS plan_xml,
p.last_compile_start_time, p.last_execution_time
FROM Query_MultPlans AS qm
JOIN sys.query_store_query AS q
    ON qm.query_id = q.query_id
JOIN sys.query_store_plan AS p
    ON q.query_id = p.query_id
JOIN sys.query_store_query_text qt 
    ON qt.query_text_id = q.query_text_id
ORDER BY query_id, plan_id;

GO


/*Get detailed info for top 25 queries with the longest execution in last hour*/
;WITH AggregatedDurationLastHour
AS
(
   SELECT q.query_id, SUM(count_executions * avg_duration) AS total_duration,
   COUNT (distinct p.plan_id) AS number_of_plans
   FROM sys.query_store_query_text AS qt JOIN sys.query_store_query AS q 
   ON qt.query_text_id = q.query_text_id
   JOIN sys.query_store_plan AS p ON q.query_id = p.query_id
   JOIN sys.query_store_runtime_stats AS rs ON rs.plan_id = p.plan_id
   JOIN sys.query_store_runtime_stats_interval AS rsi 
   ON rsi.runtime_stats_interval_id = rs.runtime_stats_interval_id
   WHERE rsi.start_time >= DATEADD(hour, -1, GETUTCDATE()) 
   AND rs.execution_type_desc = 'Regular'
   GROUP BY q.query_id
)
,OrderedDuration
AS
(
   SELECT query_id, total_duration, number_of_plans, 
   ROW_NUMBER () OVER (ORDER BY total_duration DESC, query_id) AS RN
   FROM AggregatedDurationLastHour
)
SELECT qt.query_sql_text, object_name(q.object_id) AS containing_object,
total_duration AS total_duration_microseconds, number_of_plans,
CONVERT(xml, p.query_plan) AS query_plan_xml, p.is_forced_plan, p.last_compile_start_time,q.last_execution_time
FROM OrderedDuration od JOIN sys.query_store_query AS q ON q.query_id  = od.query_id
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_plan p ON q.query_id = p.query_id
WHERE OD.RN <=25 ORDER BY total_duration DESC

GO

/*
	Queries with multiple plans among those with longest duration within last hour
	Use results to identify which plan had the best performance 
	as it can be a good candidate for plan forcing 
*/
;WITH AggregatedDurationLastHour
AS
(
   SELECT q.query_id, SUM(count_executions * avg_duration) AS total_duration,
   COUNT (distinct p.plan_id) AS number_of_plans
   FROM sys.query_store_query_text AS qt JOIN sys.query_store_query AS q 
   ON qt.query_text_id = q.query_text_id
   JOIN sys.query_store_plan AS p ON q.query_id = p.query_id
   JOIN sys.query_store_runtime_stats AS rs ON rs.plan_id = p.plan_id
   JOIN sys.query_store_runtime_stats_interval AS rsi 
   ON rsi.runtime_stats_interval_id = rs.runtime_stats_interval_id
   WHERE rsi.start_time >= DATEADD(hour, -1, GETUTCDATE()) 
   AND rs.execution_type_desc = 'Regular'
   GROUP BY q.query_id
)
,OrderedDuration
AS
(
   SELECT query_id, total_duration, number_of_plans, 
   ROW_NUMBER () OVER (ORDER BY total_duration DESC, query_id) AS RN
   FROM AggregatedDurationLastHour
)
SELECT qt.query_sql_text, object_name(q.object_id) AS containing_object, q.query_id,
p.plan_id,rsi.start_time as interval_start, rs.avg_duration,
--CONVERT(xml, p.query_plan) AS query_plan_xml
p.query_plan AS query_plan_xml
FROM OrderedDuration od JOIN sys.query_store_query AS q ON q.query_id  = od.query_id
JOIN sys.query_store_query_text AS qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_plan AS p ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats AS rs ON rs.plan_id = p.plan_id
JOIN sys.query_store_runtime_stats_interval AS rsi ON rsi.runtime_stats_interval_id = rs.runtime_stats_interval_id
WHERE rsi.start_time >= DATEADD(hour, -1, GETUTCDATE())
AND OD.RN <=25 AND number_of_plans > 1
ORDER BY total_duration DESC, query_id, rsi.runtime_stats_interval_id, p.plan_id

/*Check the state of forced plans. Inspect force_failure_reason and last_force_failure_reason_desc*/
SELECT p.plan_id, p.query_id, q.object_id as containing_object_id,
force_failure_count, last_force_failure_reason_desc
FROM sys.query_store_plan p
JOIN sys.query_store_query q on p.query_id = q.query_id
WHERE is_forced_plan = 1;
