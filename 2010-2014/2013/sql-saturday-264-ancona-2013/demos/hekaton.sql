USE master;
GO

-- create new database for testing
CREATE DATABASE HekatonDB;
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

USE HekatonDB;
GO

-- create a Memory Optimized Table
CREATE TABLE dbo.WebSessions
(
	SessionID			int				NOT NULL
,	SessionLogin		nvarchar(255)	NOT NULL
,	SessionLastLogin	datetime		NOT NULL

,	CONSTRAINT pk_WebSessions
	PRIMARY KEY NONCLUSTERED HASH (SessionID) WITH (BUCKET_COUNT = 1024) 
)
WITH (MEMORY_OPTIMIZED = ON);	-- default DURABILITY = SCHEMA_AND_DATA
GO

-- show compiled dll in xtp directory C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\DATA
-- show loaded modules
SELECT * FROM sys.dm_os_loaded_modules;
GO

-- show insert not holding exclusive locks
BEGIN TRANSACTION;
	INSERT	dbo.WebSessions (SessionID, SessionLogin, SessionLastLogin)
	VALUES	(1, N'ghotz', GETDATE());

	-- SELECT * FROM sys.dm_tran_locks WHERE request_session_id = @@SPID
	EXEC sp_lock @@spid;

COMMIT TRANSACTION;
GO

-- verify row insertion
SELECT * FROM dbo.WebSessions;
GO

-- create a natively compiled Stored Procedure to insert data
CREATE PROCEDURE dbo.InsertWebSession
	@SessionID		int
,	@SessionLogin	nvarchar(255)
WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER
AS
BEGIN ATOMIC WITH (
		TRANSACTION ISOLATION LEVEL = SNAPSHOT
	,	LANGUAGE = 'us_english'
)
	INSERT	dbo.WebSessions (SessionID, SessionLogin, SessionLastLogin)
	VALUES	(@SessionID, @SessionLogin, GETDATE());
END
GO

-- show compiled dll in xtp directory C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\DATA
-- show loaded modules
SELECT * FROM sys.dm_os_loaded_modules;
GO

-- insert some more data
EXEC dbo.InsertWebSession 2, N'dmauri';
EXEC dbo.InsertWebSession 3, N'fdechirico';
EXEC dbo.InsertWebSession 4, N'halbert';
GO

-- create a natively compiled Stored Procedure to update data
CREATE PROCEDURE dbo.UpdateWebSession
	@SessionID int
WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER
AS
BEGIN ATOMIC WITH (
		TRANSACTION ISOLATION LEVEL = SNAPSHOT
	,	LANGUAGE = 'us_english'
)
	UPDATE	dbo.WebSessions
	SET		SessionLastLogin = GETDATE()
	WHERE	SessionID = @SessionID;
END
GO

-- execute and show execution plan
EXEC dbo.UpdateWebSession 1;
GO

USE master;
GO

DROP DATABASE HekatonDB;
GO
