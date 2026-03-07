-- sysprocesses

SELECT	*
FROM	master.dbo.sysprocesses

-- informazioni utili
SELECT	loginame, hostname, program_name,  
	net_address, [context_info]
FROM	master.dbo.sysprocesses
WHERE	spid > 50

-- impostazione informazioni di contesto varbinary(128)
SET CONTEXT_INFO 0xDEADBEEF

SELECT	spid, [context_info]
FROM	master.dbo.sysprocesses
WHERE	spid > 50

SET CONTEXT_INFO 0x00000000

-- sysperfinfo
SELECT	*
FROM	master.dbo.sysperfinfo

-- contatore numero utenti
SELECT	cntr_value
FROM	master.dbo.sysperfinfo
WHERE	[object_name] = 'MSSQL$SQL2000SP:General Statistics' AND
	counter_name  = 'User Connections'

-- stored procedure di sistema
EXEC	dbo.sp_who

EXEC	dbo.sp_who2 'active'

/* Esempi caching piani di esecuzione */
-- svuoto la cache dei piani di esecuzione
-- (funziona anche con 7.0 anche se non e' documentata)
DBCC FREEPROCCACHE

-- Autoparametrazione con singolo criterio di ricerca
-- tutte le richieste SIMILI utilizzeranno lo stesso piano
SELECT * FROM Customers WHERE Country = 'UK'

SELECT cacheobjtype, usecounts, setopts, sql FROM master.dbo.syscacheobjects WHERE dbid = 6 AND sql NOT LIKE '%cache%'

SELECT * FROM Customers WHERE Country = 'Germany'

SELECT cacheobjtype, usecounts, setopts, sql FROM master.dbo.syscacheobjects WHERE dbid = 6 AND sql NOT LIKE '%cache%'

-- Non avviene l'autoparametrazione con il doppio criterio di ricerca
-- il piano di esecuzione viene comunque inserito in cache
-- e sara' utilizzato da tutte le richieste UGUALI
SELECT	* FROM Customers WHERE Country = 'UK' AND City = 'London'

SELECT cacheobjtype, usecounts, setopts, sql FROM master.dbo.syscacheobjects WHERE dbid = 6 AND sql NOT LIKE '%cache%'

SELECT	* FROM Customers WHERE Country = 'France' AND City = 'Nantes'

SELECT cacheobjtype, usecounts, setopts, sql FROM master.dbo.syscacheobjects WHERE dbid = 6 AND sql NOT LIKE '%cache%'

-- Con un criterio di ricerca in OR, il piano di esecuzione spesso non
-- viene neanche inserito in cache
DBCC FREEPROCCACHE

SELECT	* FROM Customers WHERE Country = 'UK' OR Country = 'Germany'

SELECT cacheobjtype, usecounts, setopts, sql FROM master.dbo.syscacheobjects WHERE dbid = 6 AND sql NOT LIKE '%cache%'

SELECT	* FROM Customers WHERE Country = 'France' OR Country = 'Italy'

SELECT cacheobjtype, usecounts, setopts, sql FROM master.dbo.syscacheobjects WHERE dbid = 6 AND sql NOT LIKE '%cache%'

-- se faccio una stored procedure pero'...
-- DROP PROCEDURE dbo.spTest
CREATE PROCEDURE dbo.spTest
	@Country1	nvarchar(15)='Mexico',
	@Country2	nvarchar(15)='Spain'
AS

SELECT	*
FROM	Customers
WHERE	Country = @Country1 OR
	Country = @Country2
GO

DBCC FREEPROCCACHE

-- ... il piano di esecuzione della stored procedure
-- finisce sempre in cache
EXEC	dbo.spTest 'UK', 'Germany'

SELECT cacheobjtype, usecounts, setopts, sql FROM master.dbo.syscacheobjects WHERE dbid = 6 AND sql NOT LIKE '%cache%'

EXEC	dbo.spTest 'France', 'Italy'

SELECT cacheobjtype, usecounts, setopts, sql FROM master.dbo.syscacheobjects WHERE dbid = 6 AND sql NOT LIKE '%cache%'

-- se modifico alcune impostazioni relative alla connessione
-- viene generato un nuovo execution context
SET ARITHABORT OFF

EXEC	dbo.spTest 'UK', 'Germany'

SELECT cacheobjtype, usecounts, setopts, sql FROM master.dbo.syscacheobjects WHERE dbid = 6 AND sql NOT LIKE '%cache%'

SET ARITHABORT ON

EXEC	dbo.spTest 'UK', 'Germany'

SELECT cacheobjtype, usecounts, setopts, sql FROM master.dbo.syscacheobjects WHERE dbid = 6 AND sql NOT LIKE '%cache%'

-- alternativa: utilizzando sp_executesql
EXEC	sp_executesql
	N'SELECT * FROM Customers WHERE Country = @1 OR Country = @2',
	N'@1 nvarchar(15), @2 nvarchar(15)',
	'UK', 'Germany'

SELECT cacheobjtype, usecounts, setopts, sql FROM master.dbo.syscacheobjects WHERE dbid = 6 AND sql NOT LIKE '%cache%'

EXEC	sp_executesql
	N'SELECT * FROM Customers WHERE Country = @1 OR Country = @2',
	N'@1 nvarchar(15), @2 nvarchar(15)',
	'France', 'Italy'

SELECT cacheobjtype, usecounts, setopts, sql FROM master.dbo.syscacheobjects WHERE dbid = 6 AND sql NOT LIKE '%cache%'
