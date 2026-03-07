/*
** Demo ricompilazione stored procedure
*/
USE pubs
GO

/*
** ricompilazione dovuta alla modifica di molte righe
** (solo 7.0, SQL Server 2000 non ha questo problema)
** SQL Server determina che la SP che referenzia una
** tabella temporanea deve essere ricompilata dopo
** 6 modifiche ai dati della tabella
*/

IF OBJECT_ID('dbo.spShowRecompile') IS NOT NULL
DROP PROCEDURE dbo.spShowRecompile
GO

CREATE PROCEDURE dbo.spShowRecompile
AS
SET NOCOUNT ON

DECLARE	@lngCounter integer
SET	@lngCounter = 1

CREATE TABLE #Temp(
	lngID	integer NOT NULL
)

WHILE	@lngCounter < 2000
BEGIN
	INSERT INTO #Temp VALUES(@lngCounter)
	SET @lngCounter = @lngCounter + 1 
END

SELECT COUNT(*) FROM #Temp
GO 

EXEC dbo.spShowRecompile 
GO

/*
** Soluzione 1: usare  sp_executesql
*/

IF OBJECT_ID('dbo.spShowRecompile') IS NOT NULL
DROP PROCEDURE dbo.spShowRecompile
GO

CREATE PROCEDURE dbo.spShowRecompile
AS
SET NOCOUNT ON

DECLARE	@lngCounter INTEGER
SET	@lngCounter = 1

CREATE TABLE #Temp(
	lngID	integer NOT NULL
)

WHILE	@lngCounter < 2000
BEGIN
	INSERT INTO #Temp VALUES(@lngCounter)
	SET @lngCounter = @lngCounter + 1 
END

EXEC dbo.sp_executesql N'SELECT COUNT(*) FROM #Temp'

GO 

EXEC dbo.spShowRecompile 
GO

/*
** Soluzione 2: usare l'opzione KEEPFIXED PLAN
** ATTENZIONE! Solo a partire dal SQL Server 7.0 SP3
*/

IF OBJECT_ID('dbo.spShowRecompile') IS NOT NULL
DROP PROCEDURE dbo.spShowRecompile
GO

CREATE PROCEDURE dbo.spShowRecompile
AS
SET NOCOUNT ON

DECLARE	@lngCounter INTEGER
SET	@lngCounter = 1

CREATE TABLE #Temp(
	lngID	integer NOT NULL
)

WHILE	@lngCounter < 2000
BEGIN
	INSERT INTO #Temp VALUES(@lngCounter)
	SET @lngCounter = @lngCounter + 1 
END

SELECT COUNT(*) FROM #Temp OPTION (KEEPFIXED PLAN)
GO

EXEC dbo.spShowRecompile 
GO

/*
** ricompilazione dovuta ad operazioni DML
** in mezzo ad operazioni DDL
*/
USE pubs
GO

IF OBJECT_ID('dbo.spShowRecompile') IS NOT NULL
DROP PROCEDURE dbo.spShowRecompile
GO

CREATE PROCEDURE dbo.spShowRecompile
AS
SET NOCOUNT ON

DECLARE	@lngCounter integer
SET	@lngCounter = 1

-- creazione tabella temporanea
CREATE TABLE #tTemp(
	a	integer NOT NULL,
	b	integer NULL
)

SELECT COUNT(*) FROM #tTemp

WHILE	@lngCounter < 2000
BEGIN
	INSERT INTO #tTemp(a) VALUES(@lngCounter)
	SET @lngCounter = @lngCounter + 1
END

-- creazione indice sulla tabella temporanea
CREATE CLUSTERED INDEX ind_temp ON #tTemp(a)

SELECT COUNT(*) FROM #tTemp
GO

EXEC dbo.spShowRecompile
GO

/*
** soluzione 1: raggruppamento in testa
*/
IF OBJECT_ID('dbo.spShowRecompile') IS NOT NULL
DROP PROCEDURE dbo.spShowRecompile
GO

CREATE PROCEDURE dbo.spShowRecompile
AS
SET NOCOUNT ON

DECLARE	@lngCounter integer
SET	@lngCounter = 1

-- creazione tabella temporanea
CREATE TABLE #tTemp(
	a	integer NOT NULL,
	b	integer NULL
)

-- creazione indice sulla tabella temporanea
CREATE CLUSTERED INDEX ind_temp ON #tTemp(a)

SELECT COUNT(*) FROM #tTemp

WHILE	@lngCounter < 2000
BEGIN
	INSERT INTO #tTemp(a) VALUES(@lngCounter)
	SET @lngCounter = @lngCounter + 1
END

SELECT COUNT(*) FROM #tTemp
GO

EXEC dbo.spShowRecompile
GO

/*
** soluzione 2: variabile di tipo tabella
** solo SQL Server 2000
*/
IF OBJECT_ID('dbo.spShowRecompile') IS NOT NULL
DROP PROCEDURE dbo.spShowRecompile
GO

CREATE PROCEDURE dbo.spShowRecompile
AS
SET NOCOUNT ON

DECLARE	@lngCounter integer
SET	@lngCounter = 1

-- creazione tabella temporanea
DECLARE	 @tTemp	table(
	a	integer NOT NULL,
	b	integer NULL
)

SELECT COUNT(*) FROM @tTemp

WHILE	@lngCounter < 2000
BEGIN
	INSERT INTO @tTemp(a) VALUES(@lngCounter)
	SET @lngCounter = @lngCounter + 1
END

SELECT COUNT(*) FROM @tTemp
GO

EXEC dbo.spShowRecompile
GO

/*
** Ricompilazione dovuta ad una stored procedure che referenzia
** una tabella temporanea creata da una stored procedure chiamante
*/
IF OBJECT_ID('dbo.spShowRecompileSub') IS NOT NULL
DROP PROCEDURE dbo.spShowRecompileSub
GO
CREATE PROCEDURE dbo.spShowRecompileSub
AS
SET NOCOUNT ON

SELECT COUNT(*) FROM #Temp

GO

IF OBJECT_ID('dbo.spShowRecompile') IS NOT NULL
DROP PROCEDURE dbo.spShowRecompile
GO

CREATE PROCEDURE dbo.spShowRecompile
AS
SET NOCOUNT ON
DECLARE	@lngCounter integer
SET	@lngCounter = 1

CREATE TABLE #Temp(
	lngID	integer NOT NULL
)

WHILE	@lngCounter < 2000
BEGIN
	INSERT INTO #Temp VALUES(@lngCounter)
	SET @lngCounter = @lngCounter + 1 
END

EXEC	dbo.spShowRecompileSub

GO

EXEC dbo.spShowRecompile
GO
