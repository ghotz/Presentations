USE master;
GO
DROP DATABASE HekatonDB;
-- create new database for testing
CREATE DATABASE HekatonDB;
GO

USE HekatonDB;
GO

-- TRUNCATE TABLE dbo.WebSessions;
-- create session table
CREATE TABLE dbo.WebSessions
(
	SessionID			uniqueidentifier	NOT NULL
,	SessionLogin		nvarchar(255)		NOT NULL
,	SessionLastLogin	datetime			NOT NULL
						CONSTRAINT df_WebSessions_SessionLastLogin
						DEFAULT (GETDATE())

,	CONSTRAINT pk_WebSessions
	PRIMARY KEY (SessionID)
);
GO

CREATE PROCEDURE dbo.InsertWebSession
	@SessionID		uniqueidentifier
,	@SessionLogin	nvarchar(255)
AS
BEGIN
	INSERT	dbo.WebSessions (SessionID, SessionLogin)
	VALUES	(@SessionID, @SessionLogin);
END
GO

-- add a new filegroup for MEMORY_OPTIMIZED_DATA
ALTER DATABASE HekatonDB
ADD FILEGROUP MemOptimizedData CONTAINS MEMORY_OPTIMIZED_DATA;
GO
-- add a filestream to hold data
ALTER DATABASE HekatonDB
ADD FILE
(
	NAME = N'HekatonDBFS'
,	FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\DATA\HekatonDBFS'
)
TO FILEGROUP [MemOptimizedData];
GO

-- first problem is that we can't simply alter the table
DROP TABLE dbo.WebSessions;
GO

-- create a Memory Optimized Table
CREATE TABLE dbo.WebSessions
(
	SessionID			uniqueidentifier	NOT NULL
,	SessionLogin		nvarchar(255)		NOT NULL
,	SessionLastLogin	datetime			NOT NULL
						CONSTRAINT df_WebSessions_SessionLastLogin
						DEFAULT (GETDATE())

,	CONSTRAINT pk_WebSessions
	PRIMARY KEY NONCLUSTERED HASH (SessionID) WITH (BUCKET_COUNT = 1024) 
)
WITH (MEMORY_OPTIMIZED = ON, DURABILITY=SCHEMA_ONLY);	-- default DURABILITY = SCHEMA_AND_DATA
GO

-- show compiled dll in xtp directory C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\DATA
-- show loaded modules
SELECT * FROM sys.dm_os_loaded_modules;
GO

-- show insert not holding exclusive locks
BEGIN TRANSACTION;
	INSERT	dbo.WebSessions (SessionID, SessionLogin, SessionLastLogin)
	VALUES	(NEWID(), N'ghotz', GETDATE());

	-- SELECT * FROM sys.dm_tran_locks WHERE request_session_id = @@SPID
	EXEC sp_lock @@spid;

COMMIT TRANSACTION;
GO

-- verify row insertion
SELECT * FROM dbo.WebSessions;
GO

-- again, we can't simply alter it
DROP PROCEDURE dbo.InsertWebSession;
GO

-- create a natively compiled Stored Procedure to insert data
CREATE PROCEDURE dbo.InsertWebSession
	@SessionID		uniqueidentifier
,	@SessionLogin	nvarchar(255)
WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER
AS
BEGIN ATOMIC WITH (
		TRANSACTION ISOLATION LEVEL = SNAPSHOT
	,	LANGUAGE = 'us_english'
)
	INSERT	dbo.WebSessions (SessionID, SessionLogin)
	VALUES	(@SessionID, @SessionLogin);
END
GO

-- show compiled dll in xtp directory C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\DATA
-- show loaded modules
SELECT * FROM sys.dm_os_loaded_modules;
GO

USE master;
GO

DROP DATABASE HekatonDB;
GO
