------------------------------------------------------------------------
--	Script:			en.02.delayed-durability.sql
--	Description:	Delayed Durability
--	Author:			Gianluca Hotz (SolidQ)
--	Copyright:		Attribution-NonCommercial-ShareAlike 3.0
------------------------------------------------------------------------

USE master;
GO
IF DB_ID('TestDD') IS NOT NULL
	DROP DATABASE TestDD;
GO

--	Create test database
CREATE DATABASE TestDD
	ON  PRIMARY 
	(	NAME = N'TestDB'
	,	FILENAME = N'D:\SQLServer\MSSQL12.MSSQLSERVER\MSSQL\Data\TestDB.mdf'
	, SIZE = 100MB , MAXSIZE = 2GB, FILEGROWTH = 100MB
	)
	LOG ON 
	(	NAME = N'TestDB_log'
	,	FILENAME = N'D:\SQLServer\MSSQL12.MSSQLSERVER\MSSQL\Data\TestDB_log.ldf'
	,	SIZE = 50MB, MAXSIZE = 1GB, FILEGROWTH = 50MB
	);
GO

USE TestDD;
GO

--	Initialize full recovery model
ALTER DATABASE TestDD SET RECOVERY FULL;
BACKUP DATABASE TestDD TO DISK = 'NUL';
GO

--	Create test table
CREATE TABLE dbo.WebSessions
(
	SessionID			int	IDENTITY(1, 1)	NOT NULL
,	SessionLogin		nvarchar(255)		NOT NULL
						CONSTRAINT	df_WebSessions_SessionLogin
						DEFAULT		SUSER_SNAME()
,	SessionLastLogin	datetime			NOT NULL
						CONSTRAINT df_WebSessions_SessionLastLogin
						DEFAULT		(GETDATE())
,	CONSTRAINT	pk_WebSessions
	PRIMARY KEY	(SessionID)
);
GO

--	Be sure delayed durability is disabled
ALTER DATABASE TestDD SET DELAYED_DURABILITY = DISABLED;
GO

--	Turn off row counts
SET NOCOUNT ON;
GO

--	Insert rows (7 seconds on SSD)
--	Optionally look at performance counter Databases/Log Bytes Flushed/sec
BEGIN TRANSACTION
	INSERT	dbo.WebSessions DEFAULT VALUES;
COMMIT TRANSACTION
GO 50000


--	Empty Table and T-log (to be sure no log growth is happening)
TRUNCATE TABLE dbo.WebSessions;
BACKUP LOG TestDD TO DISK = 'NUL';
GO

--	Change database settings otherwise transaction will be
--	fully durable even if WITH (DELAYED_DURABILITY=ON) is
--	specified at commit time
ALTER DATABASE TestDD SET DELAYED_DURABILITY = ALLOWED;
GO

--	Insert rows (3 seconds on SSD)
BEGIN TRANSACTION
	INSERT	dbo.WebSessions DEFAULT VALUES;
COMMIT TRANSACTION WITH (DELAYED_DURABILITY=ON);
GO 50000

--	To be sure the log is flushed
EXEC sys.sp_flush_log;
GO

--	Cleanup
USE master;
GO
IF DB_ID('TestDD') IS NOT NULL
	DROP DATABASE TestDD;
GO
