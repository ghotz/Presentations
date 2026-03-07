USE TestVardecimal
GO

------------------------------------------------------------------------
-- Creiamo le tabelle per i test
------------------------------------------------------------------------
IF OBJECT_ID('dbo.VardecimalDemoCaso3') IS NOT NULL
    DROP TABLE dbo.VardecimalDemoCaso3
GO

CREATE TABLE dbo.VardecimalDemoCaso3
(
	id	int identity	NOT NULL PRIMARY KEY
,	numero	decimal(20,10)	NULL
)
GO

------------------------------------------------------------------------
-- Caso 3
-- Inseriamo un milione di righe, in questo caso il 10% delle righe
-- contiene una valore 1 nella colonna decimal, ed un altro 10%
-- contiene NULL
------------------------------------------------------------------------
INSERT	dbo.VardecimalDemoCaso3
SELECT	CASE 
	WHEN	N.n % 10 = 0
	THEN	NULL
	WHEN	N.n % 5 = 0
	THEN	1
	ELSE	ABS(SIN(CAST(GETDATE() as decimal (20,10))) * N.n)
	END 
FROM	dbo.Numbers AS N
GO

------------------------------------------------------------------------
-- Verifichiamo i dati inseriti
------------------------------------------------------------------------
select count(*) from dbo.VardecimalDemoCaso3 where numero = 1
select count(*) from dbo.VardecimalDemoCaso3 where numero is null
GO

------------------------------------------------------------------------
-- Abilitiamo il supporto al vardecimal storage format
------------------------------------------------------------------------
EXEC	sp_db_vardecimal_storage_format 'TestVardecimal', 'on'
GO

------------------------------------------------------------------------
-- Verifichiamo l'attivazione
------------------------------------------------------------------------
EXEC	sp_db_vardecimal_storage_format 'TestVardecimal'
GO

------------------------------------------------------------------------
-- Verifichiamo lo spazio attualmente occupato dalla tabella
------------------------------------------------------------------------
EXEC	sp_spaceused 'dbo.VardecimalDemoCaso3', 'true'

------------------------------------------------------------------------
-- Stimiamo lo spazio che recuperemo per ogni riga
------------------------------------------------------------------------
EXEC	sp_estimated_rowsize_reduction_for_vardecimal 'dbo.VardecimalDemoCaso3'
SELECT	(24.00 - 20.02) * 1000000 / 1024 / 1024
GO

------------------------------------------------------------------------
-- Effetuiamo una scansione per vedere il numero di I/O
------------------------------------------------------------------------
SET STATISTICS IO ON
SELECT COUNT(*) FROM dbo.VardecimalDemoCaso3
SET STATISTICS IO OFF
GO

------------------------------------------------------------------------
-- Attiviamo il nuovo formato di storage
------------------------------------------------------------------------
EXEC	sp_tableoption 'dbo.VardecimalDemoCaso3', 'vardecimal storage format', 'on'
GO

------------------------------------------------------------------------
-- Effetuiamo una scansione per vedere il numero di I/O
------------------------------------------------------------------------
SET STATISTICS IO ON
SELECT	COUNT(*) FROM dbo.VardecimalDemoCaso3
SET STATISTICS IO OFF
GO

------------------------------------------------------------------------
-- Verifichiamo lo nuova occupazione della tabella
------------------------------------------------------------------------
EXEC	sp_spaceused 'dbo.VardecimalDemoCaso3', 'true'
GO
