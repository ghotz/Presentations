USE TestVardecimal
GO

------------------------------------------------------------------------
-- Creiamo le tabelle per i test
------------------------------------------------------------------------
IF OBJECT_ID('dbo.VardecimalDemoCaso1') IS NOT NULL
    DROP TABLE dbo.VardecimalDemoCaso1
GO

CREATE TABLE dbo.VardecimalDemoCaso1
(
	id	int identity	NOT NULL PRIMARY KEY
,	numero	decimal(20,10)	NULL
)
GO

------------------------------------------------------------------------
-- Caso 1
-- Inseriamo un milione di righe, la colonna decimal contiene dei
-- valori con un numero abbastanza uniforme di cifre
------------------------------------------------------------------------
INSERT	dbo.VardecimalDemoCaso1
SELECT	ABS(SIN(CAST(GETDATE() as decimal (20,10))) * N.n) AS numero
FROM	dbo.Numbers AS N
GO

------------------------------------------------------------------------
-- Verifichiamo i dati inseriti
------------------------------------------------------------------------
SELECT TOP 1000 * FROM dbo.VardecimalDemoCaso1
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
EXEC	sp_spaceused 'dbo.VardecimalDemoCaso1', 'true'

------------------------------------------------------------------------
-- Stimiamo lo spazio che recuperemo per ogni riga
------------------------------------------------------------------------
EXEC	sp_estimated_rowsize_reduction_for_vardecimal 'dbo.VardecimalDemoCaso1'
SELECT	(24.00 - 21.56) * 1000000 / 1024 / 1024
GO

------------------------------------------------------------------------
-- Effetuiamo una scansione per vedere il numero di I/O
------------------------------------------------------------------------
SET STATISTICS IO ON
SELECT COUNT(*) FROM dbo.VardecimalDemoCaso1
SET STATISTICS IO OFF
GO

------------------------------------------------------------------------
-- Attiviamo il nuovo formato di storage
------------------------------------------------------------------------
EXEC	sp_tableoption 'dbo.VardecimalDemoCaso1', 'vardecimal storage format', 'on'
GO

------------------------------------------------------------------------
-- Effetuiamo una scansione per vedere il numero di I/O
------------------------------------------------------------------------
SET STATISTICS IO ON
SELECT	COUNT(*) FROM dbo.VardecimalDemoCaso1
SET STATISTICS IO OFF
GO

------------------------------------------------------------------------
-- Verifichiamo lo nuova occupazione della tabella
------------------------------------------------------------------------
EXEC	sp_spaceused 'dbo.VardecimalDemoCaso1', 'true'
GO
