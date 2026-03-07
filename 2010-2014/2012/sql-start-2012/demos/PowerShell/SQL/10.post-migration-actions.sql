--
-- Template for database post-migration actions
--
-- Note: this script requires the activation of SQLCMD mode in SSMS
--

-- Script variables (uncomment to test)
-- :setvar DatabaseName AdventureWorks

USE master;
PRINT 'Start post-migration actions: ' + CONVERT(varchar, GETDATE(), 121);
GO

-- Set database in single user mode
ALTER DATABASE [$(DatabaseName)] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO

--
-- Update allocation usage
--
PRINT 'Start update allocation usage: ' + CONVERT(varchar, GETDATE(), 121);
DBCC UPDATEUSAGE([$(DatabaseName)]);
PRINT 'End update allocation usage: ' + CONVERT(varchar, GETDATE(), 121);
GO

--
-- Check database integrity
--
-- Use this query to check for DBCC execution progress and waits
--
--	SELECT	percent_complete
--	,		estimated_completion_time AS estimated_completion_time_ms
--	,		estimated_completion_time / 1000.0 / 60 AS estimated_completion_mins
--	,		wait_type
--	,		wait_time AS wait_time_ms
--	,		wait_time / 1000.0 / 60 AS wait_time_mins
--	,		wait_resource
--	,		last_wait_type
--	FROM	sys.dm_exec_requests
--	WHERE	command LIKE 'DBCC%'
--
PRINT 'Start integrity checks'': ' + CONVERT(varchar, GETDATE(), 121);
DBCC CHECKDB([$(DatabaseName)]) WITH TABLOCK, DATA_PURITY;
PRINT 'End integrity checks'': ' + CONVERT(varchar, GETDATE(), 121);
GO

--
-- Set page integrity check to level CHECKSUM
-- and compatibility level to 100 (if possible)
--
ALTER DATABASE [$(DatabaseName)] SET PAGE_VERIFY CHECKSUM;
ALTER DATABASE [$(DatabaseName)] SET COMPATIBILITY_LEVEL = 100;
GO

--
-- Statistics update
--
USE [$(DatabaseName)];
GO

PRINT 'Start statistics update: ' + CONVERT(varchar, GETDATE(), 121);
EXEC sp_updatestats;
PRINT 'End statistics update: ' + CONVERT(varchar, GETDATE(), 121);
GO

--
-- Delete orphan schemas
--
USE [$(DatabaseName)];
GO

PRINT 'Start deletion of orphan schemas: ' + CONVERT(varchar, GETDATE(), 121);
GO

DECLARE #schemas CURSOR READ_ONLY
FOR
SELECT	S1.NAME
FROM	sys.schemas AS S1
WHERE	S1.NAME NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys')
  AND	S1.SCHEMA_ID < 16384
  AND	NOT EXISTS (
		SELECT	*
		FROM	sys.objects AS O1
		WHERE	S1.SCHEMA_ID = O1.SCHEMA_ID
		);

DECLARE @schema_name sysname;

OPEN #schemas;

FETCH NEXT FROM #schemas INTO @schema_name;
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		DECLARE	@sqlstmt nvarchar(max);
		SET		@sqlstmt = 'DROP SCHEMA [' + @schema_name + ']';
		--PRINT	@sqlstmt;
		EXEC	sp_executesql @sqlstmt;
	END
	FETCH NEXT FROM #schemas INTO @schema_name;
END

CLOSE #schemas;
DEALLOCATE #schemas;
GO

PRINT 'End deletion of orphan schemas: ' + CONVERT(varchar, GETDATE(), 121);
GO

USE master;
GO

-- Set database in multi user mode
ALTER DATABASE [$(DatabaseName)] SET MULTI_USER WITH ROLLBACK IMMEDIATE;
GO

PRINT 'End post-migration actions: ' + CONVERT(varchar, GETDATE(), 121);
