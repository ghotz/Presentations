------------------------------------------------------------------------
--	Script:			en.06.system-views.sql
--	Description:	SQL Server 2014 new system views (leftover)
--	Author:			Gianluca Hotz (SolidQ)
--	Copyright:		Attribution-NonCommercial-ShareAlike 3.0
------------------------------------------------------------------------

USE AdventureWorks2012;
GO

--
--	Added 3 new columns to sys.xml_indexes
--
SELECT	xml_index_type, xml_index_type_description, path_id, *
FROM	sys.xml_indexes;
GO

--
--	sys.dm_exec_query_profiles
--	monitors real time query progress while a query is in execution
--

--	Open a second connection and execute the following
SET STATISTICS XML OFF;
SET STATISTICS PROFILE ON;
GO

SELECT * FROM Sales.vStoreWithDemographics;
GO 1000

--	Change the session_id parameter and execute
DECLARE	@session int = 53;

SELECT	node_id
,		physical_operator_name
,		SUM(row_count) row_count
,		SUM(estimate_row_count) AS estimate_row_count
FROM	sys.dm_exec_query_profiles 
WHERE	session_id = @session
GROUP BY node_id, physical_operator_name
ORDER BY node_id;

SELECT * FROM sys.dm_exec_query_profiles WHERE session_id = @session;
GO