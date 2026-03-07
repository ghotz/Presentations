/*
** Demo query distribuite
*/
USE tempdb
GO

-- Accesso a molteplici istanze di SQL Server
SELECT * FROM [P456\SQL2000SP].Northwind.dbo.Customers
SELECT * FROM [P456\SQL2000RTM].Northwind.dbo.Customers
SELECT * FROM Northwind.dbo.Customers -- locale [P456\SQL2000BETA]

-- Accesso ad un'istanza Oracle
SELECT * FROM ORCLOEMREP..SCOTT.EMP

-- Accesso ad un'istanza di DB2
SELECT * FROM TESTDB2..DBO.VALUTE

-- E' possibile modificare i dati se il provider
-- supporta le operazioni
INSERT	ORCLOEMREP..SCOTT.BONUS
VALUES	('SMITH', 'PM', 3000, 100)

DELETE	ORCLOEMREP..SCOTT.BONUS
WHERE	ENAME = 'SMITH'

/*
** Query distribuite e operazioni di restrizione
*/

-- L'operazione di restrizione viene automaticamente
-- inoltrata al server remoto
SELECT * FROM ORCLOEMREP..SCOTT.EMP WHERE SAL = 800

-- Nel caso di operazioni di restizione che implicano
-- confronti con tipi dato carattere dipende dalle
-- impostazioni di "collation" del linked server.
-- Ad esempio se non e' specificata l'opzione di
-- compatibilita, l'operazione di restrizione viene
-- eseguita localmente da SQL Server...
SELECT * FROM ORCLOEMREP..SCOTT.EMP WHERE ENAME = 'SMITH'

-- Modificando l'opzione, l'operazione puo' essere inoltrata
-- al server remoto
SELECT * FROM ORCLOEMREP..SCOTT.EMP WHERE ENAME = 'SMITH'

-- Attenzione anche all'utilizzo di funzioni, ad esempio
-- se opero una restrizione utilizzando la funzione YEAR(),
-- quest'ultima viene applicata localmente da SQL Server
SELECT * FROM ORCLOEMREP..SCOTT.EMP WHERE YEAR(HIREDATE) = 1981

-- Utilizzando la funzione OPENQUERY e' possibile
-- inoltrare la richiesta direttamente nel dialetto
-- SQL del server remoto
SELECT	*
FROM	OPENQUERY(ORCLOEMREP,
		'SELECT *
		 FROM	SCOTT.EMP
		 WHERE EXTRACT(year FROM HIREDATE) = 1981')

-- Il medesimo problema si presenta anche se il sistema
-- remoto supporta la stessa sintassi, ad esempio DB2
-- supporta la funzione YEAR(), ma...
SELECT * FROM TESTDB2..DBO.CAMBI WHERE YEAR(DATACAMBIO) = 2000

-- E' comunque necessario eseguire una query remota
SELECT	*
FROM	OPENQUERY(TESTDB2,
		'SELECT	*
		 FROM	DBO.CAMBI
		 WHERE	YEAR(DATACAMBIO) = 2000')

-- Attenzione anche alle operazioni di JOIN
SELECT	V1.DESCVALUTA
,		V2.DESCVALUTA
,		CA.DATACAMBIO
,		CA.TASSOCAMBIO
FROM	TESTDB2..DBO.CAMBI AS CA
JOIN	TESTDB2..DBO.VALUTE AS V1
  ON	CA.CODISOVALUTAORIG = V1.CODISOVALUTA
JOIN	TESTDB2..DBO.VALUTE AS V2
  ON	CA.CODISOVALUTADEST = V2.CODISOVALUTA

-- Anche in questo caso e' possibile inoltrare una
-- Query remota
SELECT	*
FROM	OPENQUERY(TESTDB2,
		'SELECT	V1.DESCVALUTA
		,		V2.DESCVALUTA
		,		CA.DATACAMBIO
		,		CA.TASSOCAMBIO
		FROM	DBO.CAMBI AS CA
		JOIN	DBO.VALUTE AS V1
		  ON	CA.CODISOVALUTAORIG = V1.CODISOVALUTA
		JOIN	DBO.VALUTE AS V2
		  ON	CA.CODISOVALUTADEST = V2.CODISOVALUTA')

