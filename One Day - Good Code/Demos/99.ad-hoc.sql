------------------------------------------------------------------------
-- Script:		ad-hoc.sql
-- Copyright:	2018 Gianluca Hotz
-- License:		MIT License
-- Credits:		https://www.red-gate.com/simple-talk/blogs/using-optimize-for-ad-hoc-workloads
------------------------------------------------------------------------
USE AdventureWorks2017;
GO

--EXEC sp_configure 'show advanced options',1
--GO
--RECONFIGURE
--GO
EXEC sp_configure 'optimize for ad hoc workloads',0
GO
RECONFIGURE
GO

DBCC FREESYSTEMCACHE ('SQL Plans')	--DBCC FREEPROCCACHE
GO
SELECT FirstName,LastName from person.person Where LastName='Raheem'
GO

select usecounts,cacheobjtype,objtype,size_in_bytes,[text]
from sys.dm_exec_cached_plans
cross apply sys.dm_exec_sql_text(plan_handle)
WHERE	[text] LIKE '%Rah%'
GO

EXEC sp_configure 'optimize for ad hoc workloads',1
GO
RECONFIGURE
GO

DBCC FREESYSTEMCACHE ('SQL Plans')	--DBCC FREEPROCCACHE
GO

-- first execution...
SELECT FirstName,LastName from person.person Where LastName='Raheem'
GO

-- ...compilation but only plan stub saved wich takes less memory
SELECT usecounts,cacheobjtype,objtype,size_in_bytes,[text]
from sys.dm_exec_cached_plans
cross apply sys.dm_exec_sql_text(plan_handle)
WHERE	[text] LIKE '%Rah%'
GO

-- second esecution...
SELECT FirstName,LastName from person.person Where LastName='Raheem'
GO

-- ...stud found, compiled and full plan left in cace
select usecounts,cacheobjtype,objtype,size_in_bytes,[text]
from sys.dm_exec_cached_plans
cross apply sys.dm_exec_sql_text(plan_handle)
WHERE	[text] LIKE '%Rah%'
GO
