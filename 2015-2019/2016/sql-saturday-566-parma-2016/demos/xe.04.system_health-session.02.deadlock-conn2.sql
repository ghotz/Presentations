------------------------------------------------------------------------
--	Deadlock demo (connessione 2)
------------------------------------------------------------------------
USE tempdb;
GO

BEGIN TRANSACTION
	SELECT * FROM dbo.TestDeadlock WITH (HOLDLOCK);
	-- passare alla prima connessione
	DELETE	dbo.TestDeadlock;

--ROLLBACK TRANSACTION;
