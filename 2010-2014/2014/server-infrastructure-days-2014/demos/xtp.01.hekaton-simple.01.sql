------------------------------------------------------------------------
--	Script:			xtp.01.hekaton-simple.01.sql
--	Description:	In-Memory OLTP Simple Demo
--	Author:			Gianluca Hotz (SolidQ)
--	Credits:		Davide Mauri (SolidQ)
--	Copyright:		Attribution-NonCommercial-ShareAlike 3.0
------------------------------------------------------------------------

USE master;
GO
IF DB_ID('HekatonDB') IS NOT NULL
	DROP DATABASE HekatonDB;
GO

--	Create new database for testing
CREATE DATABASE HekatonDB
--	ON PRIMARY 
--	(	NAME = [HekatonDB_mdf]
--	,	FILENAME = 'D:\SQLServer\MSSQL12.MSSQLSERVER\MSSQL\DATA\Hekaton_DB.mdf'
--	,	SIZE = 200MB , MAXSIZE = 2GB, FILEGROWTH = 100MB
--	)
--	LOG ON
--	(	NAME = [HekatonDB_log]
--	,	FILENAME = 'D:\SQLServer\MSSQL12.MSSQLSERVER\MSSQL\DATA\Hekaton_DB.ldf'
--	,	SIZE = 200MB , MAXSIZE = 2GB, FILEGROWTH = 100MB
--);
--GO

--	Set simple recovery model
ALTER DATABASE HekatonDB SET RECOVERY SIMPLE;
GO

USE HekatonDB;
GO

EXEC dbo.sp_changedbowner @loginame = N'sa', @map = false
GO

--
--	Create standard session table
--
IF OBJECT_ID('dbo.WebSessions_STD') IS NOT NULL
	DROP TABLE dbo.WebSessions_STD;
GO
CREATE TABLE dbo.WebSessions_STD
(
	SessionID			uniqueidentifier	NOT NULL
,	SessionLogin		nvarchar(255)		NOT NULL
,	SessionLastLogin	datetime			NOT NULL
						CONSTRAINT df_WebSessions_STD_SessionLastLogin
						DEFAULT (GETDATE())
,	PayLoad				varchar(100)		NOT NULL

,	CONSTRAINT pk_WebSessions_STD
	PRIMARY KEY NONCLUSTERED (SessionID)
);
GO

--
--	Create a standard procedure to test
--
IF OBJECT_ID('dbo.InsertTestDataWebSession_STD') IS NOT NULL
	DROP PROCEDURE dbo.InsertTestDataWebSession_STD;
GO
CREATE PROCEDURE dbo.InsertTestDataWebSession_STD
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @i int = 0;
	
	BEGIN TRANSACTION;
	WHILE @i < 10000
	BEGIN
		INSERT INTO dbo.WebSessions_STD (SessionID, SessionLogin, PayLoad)
		VALUES		(NEWID(), N'Login' + CAST(CAST(RAND()*100 AS tinyint) as VARCHAR), 'AAAAA');
		SET @i += 1;
	END
	COMMIT TRANSACTION;
END
GO

--
--	Start regular test
--	Run xtp.01.hekaton-simple.03.ostress-STD.bat
--	Add results for STD test to xtp.01.hekaton-simple.02.perf.sql
--

--	Add a new filegroup for MEMORY_OPTIMIZED_DATA
ALTER DATABASE HekatonDB
ADD FILEGROUP MemOptimizedData CONTAINS MEMORY_OPTIMIZED_DATA;
GO

--	Add a filestream to hold data
ALTER DATABASE HekatonDB
ADD FILE
(
	NAME = N'HekatonDBFS'
,	FILENAME = N'D:\SQLServer\MSSQL12.MSSQLSERVER\MSSQL\DATA\HekatonDBFS'
)
TO FILEGROUP [MemOptimizedData];
GO

--
--	Create Hekaton session table with schema and data persistence
--
IF OBJECT_ID('dbo.WebSessions_HSD') IS NOT NULL
	DROP TABLE dbo.WebSessions_HSD;
GO
CREATE TABLE dbo.WebSessions_HSD
(
	SessionID			uniqueidentifier	NOT NULL
,	SessionLogin		nvarchar(255)		NOT NULL
,	SessionLastLogin	datetime			NOT NULL
						CONSTRAINT df_WebSessions_HSD_SessionLastLogin
						DEFAULT (GETDATE())
,	PayLoad				varchar(100)		NOT NULL

,	CONSTRAINT pk_WebSessions_HSD
	PRIMARY KEY  NONCLUSTERED HASH (SessionID) WITH (BUCKET_COUNT = 100000) 
) WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA) 
GO

--
--	Create a standard procedure to test Hekaton session table with schema and data persistence
--
IF OBJECT_ID('dbo.InsertTestDataWebSession_HSD') IS NOT NULL
	DROP PROCEDURE dbo.InsertTestDataWebSession_HSD;
GO
CREATE PROCEDURE dbo.InsertTestDataWebSession_HSD
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @i int = 0;
	
	BEGIN TRANSACTION;
	WHILE @i < 10000
	BEGIN
		INSERT INTO dbo.WebSessions_STD (SessionID, SessionLogin, PayLoad)
		VALUES		(NEWID(), N'Login' + CAST(CAST(RAND()*100 AS tinyint) as VARCHAR), 'AAAAA');
		SET @i += 1;
	END
	COMMIT TRANSACTION;
END
GO

--
--	Run xtp.01.hekaton-simple.04.ostress-HSD.bat
--	Add results for STD test to xtp.01.hekaton-simple.02.perf.sql
--

--
--	Create Hekaton session table with schema only persistence
--
IF OBJECT_ID('dbo.WebSessions_HSO') IS NOT NULL
	DROP TABLE dbo.WebSessions_HSO;
GO

CREATE TABLE dbo.WebSessions_HSO
(
	SessionID			uniqueidentifier	NOT NULL
,	SessionLogin		nvarchar(255)		NOT NULL
,	SessionLastLogin	datetime			NOT NULL
						CONSTRAINT df_WebSessions_HSO_SessionLastLogin
						DEFAULT (GETDATE())
,	PayLoad				varchar(100)		NOT NULL

,	CONSTRAINT pk_WebSessions_HSO
	PRIMARY KEY  NONCLUSTERED HASH (SessionID) WITH (BUCKET_COUNT = 100000) 
) WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_ONLY) 
GO

--	Create a standard procedure to test Hekaton session table with schema only persistence
IF OBJECT_ID('dbo.InsertTestDataWebSession_HSO') IS NOT NULL
	DROP PROCEDURE dbo.InsertTestDataWebSession_HSO;
GO
CREATE PROCEDURE dbo.InsertTestDataWebSession_HSO
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @i int = 0;
	
	WHILE @i < 10000
	BEGIN
		INSERT INTO dbo.WebSessions_HSO (SessionID, SessionLogin, PayLoad)
		VALUES		(NEWID(), N'Login' + CAST(CAST(RAND()*100 AS tinyint) as VARCHAR), 'AAAAA');
		SET @i += 1;
	END
END
GO

--
--	Run xtp.01.hekaton-simple.05.ostress-HSO.bat
--	Add results for STD test to xtp.01.hekaton-simple.02.perf.sql
--

--
--	Create a natively compiled procedure to test
--	Hekaton session table with schema and data persistence
--
IF OBJECT_ID('dbo.InsertTestDataWebSession_HSD_C') IS NOT NULL
	DROP PROCEDURE dbo.InsertTestDataWebSession_HSD_C;
GO
CREATE PROCEDURE dbo.InsertTestDataWebSession_HSD_C
WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER
AS
BEGIN ATOMIC WITH (
		TRANSACTION ISOLATION LEVEL = SNAPSHOT
	,	LANGUAGE = 'us_english'
)
	DECLARE @i int = 0;
	
	WHILE @i < 10000
	BEGIN
		INSERT INTO dbo.WebSessions_HSD (SessionID, SessionLogin, PayLoad)
		VALUES		(NEWID(), N'Login' + CAST(CAST(RAND()*100 AS tinyint) as VARCHAR), 'AAAAA');
		SET @i += 1;
	END
END
GO

--
--	Run xtp.01.hekaton-simple.06.ostress-HSD_C.bat
--	Add results for STD test to xtp.01.hekaton-simple.02.perf.sql
--

--
--	Create a natively compiled procedure to test
--	Hekaton session table with schema and data persistence
--
IF OBJECT_ID('dbo.InsertTestDataWebSession_HSO_C') IS NOT NULL
	DROP PROCEDURE dbo.InsertTestDataWebSession_HSO_C;
GO
CREATE PROCEDURE dbo.InsertTestDataWebSession_HSO_C
WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER
AS
BEGIN ATOMIC WITH (
		TRANSACTION ISOLATION LEVEL = SNAPSHOT
	,	LANGUAGE = 'us_english'
)
	DECLARE @i int = 0;
	WHILE @i < 10000
	BEGIN
		INSERT INTO dbo.WebSessions_HSO (SessionID, SessionLogin, PayLoad)
		VALUES		(NEWID(), N'Login' + CAST(CAST(RAND()*100 AS tinyint) as VARCHAR), 'AAAAA');
		SET @i += 1;
	END
END
GO

--
--	Run xtp.01.hekaton-simple.07.ostress-HSO_C.bat
--	Add results for STD test to xtp.01.hekaton-simple.02.perf.sql
--

--	Show compiled dll in xtp directory D:\SQLServer\MSSQL12.MSSQLSERVER\MSSQL\DATA
--	Show loaded modules
SELECT * FROM sys.dm_os_loaded_modules;
GO

--
-- show that inserts are not holding any exclusive lock
--
BEGIN TRANSACTION;
	INSERT INTO dbo.WebSessions_HSO (SessionID, SessionLogin, PayLoad)
		VALUES		(NEWID(), N'Login' + CAST(CAST(RAND()*100 AS tinyint) as VARCHAR), 'AAAAA');

	-- SELECT * FROM sys.dm_tran_locks WHERE request_session_id = @@SPID
	EXEC sp_lock @@spid;

ROLLBACK TRANSACTION;
GO

--
-- Dealyed Durability
--

--	Change database settings otherwise transaction will be
--	fully durable even if WITH (DELAYED_DURABILITY=ON) is
--	specified at commit time
ALTER DATABASE HekatonDB SET DELAYED_DURABILITY = ALLOWED;
GO

--
--	Create a standard procedure to test with delayed durability
--
IF OBJECT_ID('dbo.InsertTestDataWebSession_STD_DD') IS NOT NULL
	DROP PROCEDURE dbo.InsertTestDataWebSession_STD_DD;
GO
CREATE PROCEDURE dbo.InsertTestDataWebSession_STD_DD
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @i int = 0;
	
	BEGIN TRANSACTION;
	WHILE @i < 10000
	BEGIN
		INSERT INTO dbo.WebSessions_STD (SessionID, SessionLogin, PayLoad)
		VALUES		(NEWID(), N'Login' + CAST(CAST(RAND()*100 AS tinyint) as VARCHAR), 'AAAAA');
		SET @i += 1;
	END
	COMMIT TRANSACTION WITH (DELAYED_DURABILITY=ON);
END
GO

--
--	Run xtp.01.hekaton-simple.08.ostress-STD_DD.bat
--	Add results for STD test to xtp.01.hekaton-simple.02.perf.sql
--

--
--	Create a standard procedure to test Hekaton session table
--	with schema and data persistence and delayed durability
--
IF OBJECT_ID('dbo.InsertTestDataWebSession_HSD_DD') IS NOT NULL
	DROP PROCEDURE dbo.InsertTestDataWebSession_HSD_DD;
GO
CREATE PROCEDURE dbo.InsertTestDataWebSession_HSD_DD
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @i int = 0;
	
	BEGIN TRANSACTION;
	WHILE @i < 10000
	BEGIN
		INSERT INTO dbo.WebSessions_HSD (SessionID, SessionLogin, PayLoad)
		VALUES		(NEWID(), N'Login' + CAST(CAST(RAND()*100 AS tinyint) as VARCHAR), 'AAAAA');
		SET @i += 1;
	END
	COMMIT TRANSACTION WITH (DELAYED_DURABILITY=ON);
END
GO

--
--	Run xtp.01.hekaton-simple.09.ostress-HSD_DD.bat
--	Add results for STD test to xtp.01.hekaton-simple.02.perf.sql
--

--
--	Create a natively compiled procedure to test
--	Hekaton session table with schema and data persistence
--	and Delayed Durability
--
IF OBJECT_ID('dbo.InsertTestDataWebSession_HSD_C_DD') IS NOT NULL
	DROP PROCEDURE dbo.InsertTestDataWebSession_HSD_C_DD;
GO
CREATE PROCEDURE dbo.InsertTestDataWebSession_HSD_C_DD
WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER
AS
BEGIN ATOMIC WITH (
		TRANSACTION ISOLATION LEVEL = SNAPSHOT
	,	LANGUAGE = 'us_english'
	,	DELAYED_DURABILITY=ON
)
	DECLARE @i int = 0;
	
	WHILE @i < 10000
	BEGIN
		INSERT INTO dbo.WebSessions_HSD (SessionID, SessionLogin, PayLoad)
		VALUES		(NEWID(), N'Login' + CAST(CAST(RAND()*100 AS tinyint) as VARCHAR), 'AAAAA');
		SET @i += 1;
	END
END
GO

--
--	Run xtp.01.hekaton-simple.10.ostress-HSD_C_DD.bat
--	Add results for STD test to xtp.01.hekaton-simple.02.perf.sql
--

--
--	Cleanup
--
USE master;
GO
IF DB_ID('HekatonDB') IS NOT NULL
	DROP DATABASE HekatonDB;
GO
