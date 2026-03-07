USE TestVardecimal
GO

------------------------------------------------------------------------
-- Creiamo le tabelle per i test
------------------------------------------------------------------------
IF OBJECT_ID('dbo.VardecimalDemoCaso4') IS NOT NULL
    DROP TABLE dbo.VardecimalDemoCaso4
GO

CREATE TABLE dbo.VardecimalDemoCaso4
(
	id	int identity	NOT NULL PRIMARY KEY
,	numero	decimal(20,10)	NULL
)
GO

------------------------------------------------------------------------
-- Caso 4
-- Inseriamo un milione di righe, in questo caso il 20% delle righe
-- contiene NULL nella colonna decimal
------------------------------------------------------------------------
INSERT	dbo.VardecimalDemoCaso4
SELECT	CASE 
	WHEN	N.n % 5 = 0
	THEN	NULL
	ELSE	abs(sin(cast(getdate() as decimal (20,10))) * N.n)
	END 
FROM	dbo.Numbers AS N
GO

------------------------------------------------------------------------
-- Verifichiamo i dati inseriti
------------------------------------------------------------------------
select count(*) from dbo.VardecimalDemoCaso4 where numero is null
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
EXEC	sp_spaceused 'dbo.VardecimalDemoCaso4', 'true'

------------------------------------------------------------------------
-- Stimiamo lo spazio che recuperemo per ogni riga
------------------------------------------------------------------------
EXEC	sp_estimated_rowsize_reduction_for_vardecimal 'dbo.VardecimalDemoCaso4'
SELECT	(24.00 - 19.80) * 1000000 / 1024 / 1024
GO

------------------------------------------------------------------------
-- Effetuiamo una scansione per vedere il numero di I/O
------------------------------------------------------------------------
SET STATISTICS IO ON
SELECT COUNT(*) FROM dbo.VardecimalDemoCaso4
SET STATISTICS IO OFF
GO

------------------------------------------------------------------------
-- Attiviamo il nuovo formato di storage
------------------------------------------------------------------------
EXEC	sp_tableoption 'dbo.VardecimalDemoCaso4', 'vardecimal storage format', 'on'
GO

------------------------------------------------------------------------
-- Effetuiamo una scansione per vedere il numero di I/O
------------------------------------------------------------------------
SET STATISTICS IO ON
SELECT	COUNT(*) FROM dbo.VardecimalDemoCaso4
SET STATISTICS IO OFF
GO

------------------------------------------------------------------------
-- Verifichiamo lo nuova occupazione della tabella
------------------------------------------------------------------------
EXEC	sp_spaceused 'dbo.VardecimalDemoCaso4', 'true'
GO
