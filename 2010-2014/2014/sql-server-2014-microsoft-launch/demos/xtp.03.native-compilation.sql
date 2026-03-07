------------------------------------------------------------------------
--	Script:			xtp.03.native-compilation
--	Description:	In-Memory OLTP Native Compilation
--	Author:			Igor Pagliai (Microsoft)
--	Copyright:		Attribution-NonCommercial-ShareAlike 3.0
------------------------------------------------------------------------

--
--	Check the default DATA folder location for the instance
--		D:\SQLServer\MSSQL12.MSSQLSERVER\MSSQL\DATA
--	Check compiler location
--		C:\Program Files\Microsoft SQL Server\MSSQL12.SQL2014\MSSQL\Binn\Xtp\VC\bin

USE master;
GO
SET NOCOUNT ON
GO

--
--	Database creation
--
IF DB_ID('ContosoOLTP') IS NOT NULL
	DROP DATABASE ContosoOLTP;
GO

CREATE DATABASE ContosoOLTP
	ON PRIMARY 
	(	NAME = [ContosoOLTP_mdf]
	,	FILENAME = 'C:\temp\hekaton\ContosoOLTP.mdf'
	,	SIZE = 100MB , MAXSIZE = 2GB, FILEGROWTH = 100MB
	)
,	FILEGROUP [ContosoOLTP_mod] CONTAINS MEMORY_OPTIMIZED_DATA 
	(	NAME = [ContosoOLTP_container1]
	,	FILENAME = 'C:\temp\hekaton\ContosoOLTP_container1'
	)
	LOG ON
	(	NAME = [ContosoOLTP_log]
	,	FILENAME = 'C:\temp\hekaton\ContosoOLTP.ldf'
	,	SIZE = 100MB , MAXSIZE = 2GB, FILEGROWTH = 100MB
	);
GO

USE ContosoOLTP
GO

--	Drop objects if they already exists
IF EXISTS (SELECT * FROM sys.objects WHERE name='InsertOrders')
	DROP PROC dbo.InsertOrders;
GO
IF EXISTS (SELECT * FROM sys.objects WHERE name='SalesOrders')
	DROP TABLE dbo.SalesOrders;
GO

--	Create In-Memory Optimized Table
CREATE TABLE dbo.SalesOrders
(	order_id		int			NOT NULL
,	order_date		datetime2	NOT NULL
,	order_status	tinyint		NOT NULL
,	CONSTRAINT	pk_SalesOrders
	PRIMARY KEY NONCLUSTERED HASH (order_id)
	WITH (BUCKET_COUNT = 2000000)
,	INDEX ix_SalesOrders_orderdate
	NONCLUSTERED (order_date ASC, order_id ASC)
) WITH (MEMORY_OPTIMIZED = ON);
GO

--	Check database ID (e.g. 10)
--	Show generated files in "D:\SQLServer\MSSQL12.MSSQLSERVER\MSSQL\DATA\xtp\10"
SELECT DB_ID('ContosoOLTP');
GO

-- Check object_id for in-memory table (e.g. 277576027)
-- Verify generated files in "D:\SQLServer\MSSQL12.MSSQLSERVER\MSSQL\DATA\xtp\10"
SELECT	name, [object_id], is_memory_optimized, [durability], durability_desc 
FROM	sys.tables
WHERE	[type]='U';
GO

--	Create T-SQL stored procedure to insert in memory optimized table
CREATE PROCEDURE dbo.InsertOrders_TSQL
WITH EXECUTE AS OWNER
AS 
BEGIN 
	DECLARE	@id int = 1;
	DECLARE	@status tinyint = 1;
	BEGIN TRAN
		WHILE @id <= 1000000
		BEGIN
			INSERT dbo.SalesOrders VALUES (@id, GETDATE(), @status);
			SET @id += 1;
		END
	COMMIT TRAN
END
GO

--	Clear procedure cache
DBCC FREEPROCCACHE
GO

--	Insert 1 milion records
EXEC dbo.InsertOrders_TSQL;
GO

--	Check CPU time and Elapse time
--	e.g. = CPU 5805ms, Elapsed Time 6507ms (on VM with 8 cores 16GB RAM)
--	e.g. = CPU 9008ms, Elapsed Time 9581ms (on laptop 8 cores 16GB RAM)
SELECT [last_worker_time]/1000 as 'CPU Time (ms)',
       [last_elapsed_time]/1000 as 'Elapsed Time (ms)' 
FROM	sys.dm_exec_procedure_stats;
GO

--	Try to empty in-memory table... doesn't work
TRUNCATE TABLE dbo.SalesOrders;
GO
--	Delete statement needed
DELETE FROM dbo.SalesOrders;
GO

--	Create native stored procedure to insert in memory optimized table
CREATE PROCEDURE dbo.InsertOrders_HKT 
WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER
AS 
BEGIN ATOMIC WITH (
	TRANSACTION ISOLATION LEVEL = SNAPSHOT
,	LANGUAGE = N'us_english'
)
	DECLARE	@id int = 1;
	DECLARE	@status tinyint = 1;

	WHILE @id <= 1000000
	BEGIN
		INSERT dbo.SalesOrders VALUES (@id, GETDATE(), @status);
		SET @id += 1;
	END
END	-- Atomic
GO

--	Check system catalog (look at use_native_compilation)
SELECT * FROM sys.sql_modules;
GO

--	Check object_id for native procedure (e.g. 325576198)
--	Verify generated files in "D:\SQLServer\MSSQL12.MSSQLSERVER\MSSQL\DATA\xtp\10"
--	Note XTP_P* and XTP_T*
SELECT	[name], [object_id]
FROM	sys.procedures
WHERE	[name] = 'InsertOrders_HKT';
GO

--	Show execution statistics
SET STATISTICS TIME ON;
EXEC dbo.InsertOrders_HKT;
SET STATISTICS TIME OFF;
GO
--	Check CPU time and Elapse time
--	e.g. = CPU time = 1344ms,  elapsed time = 2278ms.
--	e.g. = CPU time = 1969 ms,  elapsed time = 2835 ms.

--
--	troubleshooting native compilation
--

--	Add additional info in the OUT file
DBCC TRACEON(9830, -1) 
GO
CREATE PROCEDURE dbo.InsertOrders_HKT2
WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER
AS 
BEGIN ATOMIC WITH (
	TRANSACTION ISOLATION LEVEL = SNAPSHOT
,	LANGUAGE = N'us_english'
)
	DECLARE	@id int = 1;
	DECLARE	@status tinyint = 1;

	WHILE @id <= 1000000
	BEGIN
		INSERT dbo.SalesOrders VALUES (@id, GETDATE(), @status);
		SET @id += 1;
	END
END	-- Atomic
GO

--	Check object_id for native procedure (e.g. 357576312)
--	Verify generated files in "D:\SQLServer\MSSQL12.MSSQLSERVER\MSSQL\DATA\xtp\10"
--	Compare different *.OUT file
--	Check also ERRORLOG
SELECT	[name], [object_id]
FROM	sys.procedures
WHERE	[name] = 'InsertOrders_HKT2';
GO

--
--	Simulate a compile failure
--

--	Rename "CL.EXE" in "C:\Program Files\Microsoft SQL Server\MSSQL12.SQL2014\MSSQL\Binn\Xtp\VC\bin"
--	Try creating a new native compiled procedure
CREATE PROCEDURE dbo.InsertOrders_HKT3
WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER
AS 
BEGIN ATOMIC WITH (
	TRANSACTION ISOLATION LEVEL = SNAPSHOT
,	LANGUAGE = N'us_english'
)
	DECLARE	@id int = 1;
	DECLARE	@status tinyint = 1;

	WHILE @id <= 1000000
	BEGIN
		INSERT dbo.SalesOrders VALUES (@id, GETDATE(), @status);
		SET @id += 1;
	END
END	-- Atomic
GO

--	QUESTION: What would happen if now I will restart SQL Server?
--	ANSWER: Pending recovery...

--	Rename back "CL.EXE" in "C:\Program Files\Microsoft SQL Server\MSSQL12.SQL2014\MSSQL\Binn\Xtp\VC\bin"
ALTER DATABASE ContosoOLTP SET ONLINE;
GO

-- RENAME back the CL.EXE compiler file --
-- RETRY COMPILATION of previous code

--	Smart C-Compiler or Smart SQL Query Processor??
--	QUESTION: What will happen compiling the following procedure?
CREATE PROCEDURE dbo.DivideByZero
WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER
AS 
BEGIN ATOMIC WITH (
	TRANSACTION ISOLATION LEVEL = SNAPSHOT
,	LANGUAGE = N'us_english'
)
	SELECT 1/0;
END
GO

--
--	Cleanup
--
USE master;
GO
IF DB_ID('ContosoOLTP') IS NOT NULL
	DROP DATABASE ContosoOLTP;
GO
