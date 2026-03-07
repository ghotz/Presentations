------------------------------------------------------------------------
-- Creiamo un database di supporto per i test
------------------------------------------------------------------------
IF EXISTS(SELECT * FROM sysdatabases WHERE name = 'TestVardecimal')
	DROP DATABASE TestVardecimal
GO

CREATE DATABASE TestVardecimal
GO

ALTER DATABASE TestVardecimal SET RECOVERY SIMPLE
GO

USE TestVardecimal
GO

------------------------------------------------------------------------
-- Creiamo una tabella di supporto con numeri interi da 1 a 1 milione.
------------------------------------------------------------------------
IF OBJECT_ID('dbo.Numbers') IS NOT NULL
	DROP TABLE dbo.Numbers;

CREATE TABLE dbo.Numbers(n int NOT NULL PRIMARY KEY);

DECLARE	@MaxNumber	int
,	@RowCount	int;

SET	@MaxNumber = 1000000;
SET	@RowCount = 1;

INSERT dbo.Numbers VALUES(1);

WHILE	@RowCount * 2 <= @MaxNumber
BEGIN
	INSERT	dbo.Numbers 
	SELECT	n + @RowCount
	FROM	dbo.Numbers;

	SET	@RowCount = @RowCount * 2;
END

INSERT	dbo.Numbers 
SELECT	n + @RowCount
FROM	dbo.Numbers
WHERE	n + @RowCount <= @MaxNumber;

CHECKPOINT
GO
