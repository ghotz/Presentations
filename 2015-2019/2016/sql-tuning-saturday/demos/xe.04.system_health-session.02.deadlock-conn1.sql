------------------------------------------------------------------------
--	Deadlock demo (connessione 1)
------------------------------------------------------------------------
USE tempdb;
GO

IF OBJECT_ID('dbo.TestDeadlock') IS NOT NULL
	DROP TABLE dbo.TestDeadlock
GO

CREATE TABLE dbo.TestDeadlock (Field1 int NOT NULL IDENTITY (1, 1) PRIMARY KEY);
GO

INSERT dbo.TestDeadlock DEFAULT VALUES;
GO

BEGIN TRANSACTION
	SELECT * FROM dbo.TestDeadlock WITH (HOLDLOCK);
	-- passare alla seconda connessione
	DELETE	dbo.TestDeadlock;
	-- passare alla seconda connessione

ROLLBACK TRANSACTION;
