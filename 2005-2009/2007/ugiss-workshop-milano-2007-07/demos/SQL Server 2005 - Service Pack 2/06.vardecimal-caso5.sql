USE TestVardecimal
GO

------------------------------------------------------------------------
-- Creiamo le tabelle per i test
------------------------------------------------------------------------
IF OBJECT_ID('dbo.VardecimalDemoCaso5') IS NOT NULL
    DROP TABLE dbo.VardecimalDemoCaso5
GO

CREATE TABLE dbo.VardecimalDemoCaso5
(
	id	int identity	NOT NULL PRIMARY KEY
,	numero	decimal(20,10)	NULL
)
GO

------------------------------------------------------------------------
-- Caso 5
-- Inseriamo un milione di righe, in questo caso il 20% delle righe
-- contiene un valore 0 nella colonna decimal
------------------------------------------------------------------------
INSERT	dbo.VardecimalDemoCaso5
SELECT	CASE 
	WHEN	N.n % 5 = 0
	THEN	0
	ELSE	abs(sin(cast(getdate() as decimal (20,10))) * N.n)
	END 
FROM	dbo.Numbers AS N
GO

------------------------------------------------------------------------
-- Verifichiamo i dati inseriti
------------------------------------------------------------------------
select count(*) from dbo.VardecimalDemoCaso5 where numero = 0
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
EXEC	sp_spaceused 'dbo.VardecimalDemoCaso5', 'true'

------------------------------------------------------------------------
-- Stimiamo lo spazio che recuperemo per ogni riga
------------------------------------------------------------------------
EXEC	sp_estimated_rowsize_reduction_for_vardecimal 'dbo.VardecimalDemoCaso5'
SELECT	(24.00 - 19.94) * 1000000 / 1024 / 1024
GO

------------------------------------------------------------------------
-- Effetuiamo una scansione per vedere il numero di I/O
------------------------------------------------------------------------
SET STATISTICS IO ON
SELECT COUNT(*) FROM dbo.VardecimalDemoCaso5
SET STATISTICS IO OFF
GO

------------------------------------------------------------------------
-- Attiviamo il nuovo formato di storage
------------------------------------------------------------------------
EXEC	sp_tableoption 'dbo.VardecimalDemoCaso5', 'vardecimal storage format', 'on'
GO

------------------------------------------------------------------------
-- Effetuiamo una scansione per vedere il numero di I/O
------------------------------------------------------------------------
SET STATISTICS IO ON
SELECT	COUNT(*) FROM dbo.VardecimalDemoCaso5
SET STATISTICS IO OFF
GO

------------------------------------------------------------------------
-- Verifichiamo lo nuova occupazione della tabella
------------------------------------------------------------------------
EXEC	sp_spaceused 'dbo.VardecimalDemoCaso5', 'true'
GO
