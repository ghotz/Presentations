------------------------------------------------------------------------
--	Script:			xtp.02.hekaton-storage
--	Description:	In-Memory OLTP Storage
--	Author:			Igor Pagliai (Microsoft)
--	Copyright:		Attribution-NonCommercial-ShareAlike 3.0
------------------------------------------------------------------------
USE master
GO

--
--	Database creation
--
IF DB_ID('Hekaton_DB') IS NOT NULL
	DROP DATABASE Hekaton_DB;
GO

CREATE DATABASE Hekaton_DB
	ON PRIMARY 
	(	NAME = [Hekaton_DB_hk_fs_data]
	,	FILENAME = 'C:\temp\hekaton\Hekaton_DB_data.mdf'
	,	SIZE = 100MB , MAXSIZE = 2GB, FILEGROWTH = 100MB
	)
,	FILEGROUP [Hekaton_DB_FG] CONTAINS MEMORY_OPTIMIZED_DATA 
	(	NAME = [hekaton_db_container1]
	,	FILENAME = 'C:\temp\hekaton\Hekaton_DB_hk_fs_dir_container1'
	)
	LOG ON
	(	NAME = [hktest_log]
	,	FILENAME = 'C:\temp\hekaton\Hekaton_DB.ldf'
	,	SIZE = 100MB , MAXSIZE = 2GB, FILEGROWTH = 100MB
	);
GO

USE Hekaton_DB
GO

--	Create a simple Hekaton table
CREATE TABLE dbo.t_hk (
	c1	int			NOT NULL
,	c2	char(100)	NOT NULL
,	CONSTRAINT pk_t_hk
	PRIMARY KEY NONCLUSTERED HASH (c1) 
	WITH(BUCKET_COUNT = 1000000)
)
WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA);
GO

--	Create a similar disk based table
CREATE TABLE dbo.t_disk (
	c1	int			NOT NULL
,	c2	char(100)	NOT NULL
);
GO

--	Create the index similar to the one we have
--	for the memory-optimized table
CREATE UNIQUE NONCLUSTERED INDEX pk_t_disk
ON	dbo.t_disk(c1);
GO

--	Insert 100 rows under a single transaction in disk based table
BEGIN TRAN
	DECLARE @i INT = 0;
	WHILE (@i < 100)
	BEGIN
		INSERT dbo.t_disk VALUES (@i, REPLICATE ('1', 100));
		SET @i = @i + 1;
	END
COMMIT TRANSACTION;
GO


--	You will see that SQL Server logged 200 log records: why 200 and not 100?
SELECT	* 
FROM	sys.fn_dblog(NULL, NULL) as t_log
JOIN	sys.partitions as t_part 
  ON	t_log.PartitionId = t_part.[partition_id]
WHERE	t_part.[object_id] = OBJECT_ID('t_disk');
GO

--	Insert 100 rows under a single transaction in hekaton table
--	Note each row is approx 100 bytes each
BEGIN TRAN
	DECLARE @i INT = 0;
	WHILE (@i < 100)
	BEGIN
		INSERT dbo.t_hk VALUES (@i, REPLICATE ('1', 100));
		SET @i = @i + 1;
	END
COMMIT TRANSACTION;
GO

--	Look at the log (note last line 12K log record)
SELECT * FROM sys.fn_dblog(NULL, NULL) WHERE operation = 'LOP_HK';
GO

--	We can then look inside the last big log record
SELECT
	[Current LSN]
,	[Transaction ID]
,	Operation
,	operation_desc
,	tx_end_timestamp
,	total_size
,	OBJECT_NAME(table_id) AS table_name
FROM	sys.fn_dblog_xtp(null, null)
WHERE	[Log Record Length] > 10000;	-- log record > 10000 bytes
--WHERE [Current LSN] = '00000022:000001cf:0003'	-- record LSN
GO

--	Size of the single log record
SELECT
	COUNT([current lsn]) AS [# Packed transactions]
,	SUM(total_size) AS [Total Size of single log record (bytes)]
FROM	sys.fn_dblog_xtp(null, null)
WHERE	[Log Record Length] > 10000;
GO

--	Look to some DMVs
--	Note the inserted rows (inserted_row_count = 100 in data file)
SELECT * FROM sys.dm_db_xtp_checkpoint_files WHERE [state] <> 0;
GO

--	Generate some updates
UPDATE	dbo.t_hk WITH (SNAPSHOT)
SET		c2 = REPLICATE ('2', 100);
GO

--	Look again at DMV
--	Note the DELETED rows (100) and INSERTED rows (100+100)!
SELECT * FROM sys.dm_db_xtp_checkpoint_files WHERE [state] <> 0;
GO

--
--	Transaction log used by disk and in-memory tables
--

--	Index maintenance
ALTER INDEX pk_t_disk ON dbo.t_disk REBUILD;	-- logged operation!
ALTER INDEX pk_t_hk ON t_hk REBUILD;			-- What happen here in your opinion?
GO

--	Aborted transactions (disk table)
SELECT	SUM([Log Record Length]) AS [Log Record used (bytes)]
,		SUM([Log Reserve]) AS [Space for rollback (bytes)]
FROM	sys.fn_dblog(NULL, NULL) as t_log
JOIN	sys.partitions as t_part 
  ON	t_log.PartitionId = t_part.[partition_id]
WHERE	t_part.[object_id] = OBJECT_ID('t_disk');
GO

--	Remember the numbers above, i.e. = 20400 + 17800
--	Execute and rollback a transaction
BEGIN TRANSACTION
	UPDATE	dbo.t_disk
	SET		c2 = REPLICATE('3', 100);
ROLLBACK TRANSACTION
GO

--	Check transaction log usage again
SELECT	SUM([Log Record Length]) AS [Log Record used (bytes)]
,		SUM([Log Reserve]) AS [Space for rollback (bytes)]
FROM	sys.fn_dblog(NULL, NULL) as t_log
JOIN	sys.partitions as t_part 
  ON	t_log.PartitionId = t_part.[partition_id]
WHERE	t_part.[object_id] = OBJECT_ID('t_disk');
GO
--	Compare with the previous numbers, i.e. = 67600 + 40200

--	Check for Hekaton table
SELECT	SUM([Log Record Length]) AS [Log Record used (bytes)]
,		SUM([Log Reserve]) AS [Space for rollback (bytes)]
FROM	sys.fn_dblog(NULL, NULL)
WHERE	operation = 'LOP_HK';
--	Remember the numbers above, i.e. = 37828 + 0

BEGIN TRANSACTION
	UPDATE	dbo.t_hk WITH (SNAPSHOT)
	SET		c2 = REPLICATE('4', 100);
ROLLBACK TRANSACTION
GO

SELECT	SUM([Log Record Length]) AS [Log Record used (bytes)]
,		SUM([Log Reserve]) AS [Space for rollback (bytes)]
FROM	sys.fn_dblog(NULL, NULL)
WHERE	operation = 'LOP_HK';
--	Compare with the previous numbers ! --

--
--	Force checkpoint
--
CHECKPOINT;
GO

--
--	Test DBCC CHECKDB
--
DBCC CHECKDB	-- Search for "t_hk" object and see what is reported (not supported)
GO

USE master
GO

--
--	Recovery example
--

--	set the database offline
ALTER DATABASE hekaton_db SET OFFLINE;
GO

--	Rename "Hekaton_DB_hk_fs_dir_container1" to something else
--	to simulate a loss of Hekaton checkpoint files.

--	Set the database online (error is expected)
ALTER DATABASE hekaton_db SET ONLINE;
GO

--	Database is in recovery pending
SELECT [name], [state_desc] FROM sys.databases WHERE [name] = 'Hekaton_DB';
GO

--	Take Hekaton FG offline
ALTER DATABASE hekaton_db MODIFY FILE (name = 'hekaton_db_container1', OFFLINE);
--	WARNING: No point of return!
GO

ALTER DATABASE hekaton_db SET ONLINE;
GO

-- Test access to both tables
SELECT * FROM Hekaton_DB.dbo.t_disk;	-- Disk based table
SELECT * FROM Hekaton_DB.dbo.t_hk;		-- In-Memory optimized table
GO

--
--	Cleanup
--
USE master
GO
IF DB_ID('Hekaton_DB') IS NOT NULL
	DROP DATABASE Hekaton_DB;
GO
