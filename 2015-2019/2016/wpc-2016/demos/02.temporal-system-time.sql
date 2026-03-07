------------------------------------------------------------------------
--	Script:		02.temporal-system-time
--	Copyright:	2016 Gianluca Hotz
--	License:	MIT License
--	Credits:		
------------------------------------------------------------------------
--USE master;
--GO

----
---- Create test database
----
--IF EXISTS(SELECT * FROM sys.databases WHERE name = 'TemporalDB')
--BEGIN
--	ALTER DATABASE TemporalDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
--	DROP DATABASE TemporalDB;
--END
--CREATE DATABASE TemporalDB;
--GO

USE TemporalDB;
GO
--
-- CLEANUP
--
IF EXISTS(SELECT * FROM sys.tables WHERE [name] = 'SP' AND temporal_type > 0)
	ALTER TABLE [SP] SET (SYSTEM_VERSIONING = OFF);
DROP TABLE IF EXISTS [SP];
DROP TABLE IF EXISTS [HISTORY].[SP_HIST];
IF EXISTS(SELECT * FROM sys.tables WHERE [name] = 'S' AND temporal_type > 0)
	ALTER TABLE [S] SET (SYSTEM_VERSIONING = OFF);
DROP TABLE IF EXISTS [S];
DROP TABLE IF EXISTS [HISTORY].[S_HIST];
DROP SCHEMA IF EXISTS [HISTORY];
GO
--
-- DEMO 01: aggiungere gestione temporale a una tabella esistente
--
-- Tabella che si riferisce alla relazione
-- S {S#, NAME, CITY} KEY {S#}
--
-- Predicato: il fornitore identificato da <S#>, con nome <SNAME>,
-- con sede nella città <CITY>, ha un contratto in corso (correntemente).
--
-- DROP TABLE IF EXISTS [S];
CREATE TABLE [S] (
	[S#]	int			NOT NULL
,	[NAME]	varchar(20)	NOT NULL
,	[CITY]	varchar(20)	NOT NULL
,	CONSTRAINT PK_S PRIMARY KEY ([S#])
);
GO

-- inseriamo alcuni dati di prova
SET NOCOUNT ON;
INSERT	[S] VALUES (1, 'Gianluca',	'Varese');
INSERT	[S] VALUES (2, 'Davide',	'Milano');
INSERT	[S] VALUES (3, 'Andrea',	'Brescia');
INSERT	[S] VALUES (4, 'Francesco', 'Milano');
SET NOCOUNT OFF;
GO

-- proviamo a impostare la tabella come System-Versioned 
ALTER TABLE [S] SET (SYSTEM_VERSIONING = ON);
GO

-- dobbiamo prima definire gli attributi che saranno usati per indicare
-- il periodo temporale durante il quale si ritiene la proposizione
-- (la riga) valida e dobbiamo definire dei valori di default per le
-- righe già presenti nella tabella
--
-- Nota: 
ALTER TABLE [S]
ADD
	[S_FROM]	datetime2(0) GENERATED ALWAYS AS ROW START HIDDEN
				CONSTRAINT DF_S_FROM DEFAULT CONVERT(datetime2 (0), '2016-11-01 00:00:00')
				-- CONSTRAINT DF_S_FROM DEFAULT CAST(CONVERT(char(8), SYSUTCDATETIME(), 112) AS datetime2(0))

,	[S_TO]		datetime2(0) GENERATED ALWAYS AS ROW END HIDDEN
				CONSTRAINT DF_S_TO DEFAULT CONVERT(datetime2(0), '9999-12-31 23:59:59')

,	PERIOD FOR SYSTEM_TIME ([S_FROM], [S_TO]);
GO

-- ora possiamo impostare la tabella come System-Versioned 
ALTER TABLE [S] SET (SYSTEM_VERSIONING = ON);
GO

-- avendo creato le colonne del periodo "HIDDEN", non vengono visualizzate
SELECT * FROM [S];
GO
-- devono essere esplicitamente referenziate in modo da risultare
-- trasparenti alle attuale applicazioni
SELECT *, [S_FROM], [S_TO] FROM [S];
GO

-- senza specificare altro, la tabella di storico viene posizionata nello
-- stesso schema e le viene assegnato un nome generato internamente
SELECT	[object_id], SCHEMA_NAME([schema_id]) AS [schema], [name]
,		[type_desc], [temporal_type], [temporal_type_desc], [history_table_id]
FROM	sys.tables;
GO

-- solitamente è preferibile specificare sia uno schema alternativo
-- che un nome ben preciso, creiamo quindi uno schema che conterrà le
-- tabelle di storico
CREATE SCHEMA HISTORY;
GO

-- prima di cambiare direttamente la tabella spceificando schema e nome, 
--  dobbiamo disabilitare il system-versioning dalla tabella
BEGIN TRANSACTION;
	ALTER TABLE [S] SET (SYSTEM_VERSIONING = OFF);
	ALTER TABLE [S] SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = HISTORY.S_HIST));
COMMIT TRANSACTION;
GO

-- verifichiamo i nuovi metadati (vecchia tabella ancora disponibile)
SELECT	[object_id], SCHEMA_NAME([schema_id]) AS [schema], [name]
,		[type_desc], [temporal_type], [temporal_type_desc], [history_table_id]
FROM	sys.tables;
GO

-- la tabella di storico ha uno schema speculare a quella sorgente
EXEC sp_help 'HISTORY.S_HIST';
GO

-- viene creato un indice clustered che comprende le colonne del periodo
EXEC sp_helpindex 'HISTORY.S_HIST';
GO

-- l'indice è compresso (da 2016 SP1 disponibile anche nella standard)
SELECT	I.[name], I.[type_desc], P.data_compression_desc
FROM	sys.indexes AS I
JOIN	sys.partitions AS P
  ON	I.[object_id] = P.[object_id]
 AND	I.[index_id] = P.[index_id]
WHERE	I.[object_id] = OBJECT_ID('HISTORY.S_HIST');
GO

--
-- DEMO 02 creare una nuova tabella con gestione temporale
--
-- Tabella che si riferisce alla relazione
-- SP {S#, P#, PRICE} KEY {S#, #P}
--
-- Predicato: il fornitore identificato da <S#> fornisce correntemente
-- il prodotto identificato da <P#> al prezzo <PRICE>.
--
CREATE TABLE [SP] (
	[S#]		int			NOT NULL
,	[P#]		int			NOT NULL
,	[PRICE]		money		NOT NULL

,	[SP_FROM]	datetime2(0) GENERATED ALWAYS AS ROW START HIDDEN NOT NULL
,	[SP_TO]		datetime2(0) GENERATED ALWAYS AS ROW END HIDDEN NOT NULL
,	PERIOD FOR SYSTEM_TIME ([SP_FROM], [SP_TO])

,	CONSTRAINT PK_SP PRIMARY KEY ([S#], [P#])
,	CONSTRAINT FK_SP_TO_S FOREIGN KEY ([S#]) REFERENCES [S]([S#])
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = HISTORY.SP_HIST));
GO

-- non si possono inserire valori espliciti per le colonne del periodo
INSERT	[SP] ([S#], [P#], [PRICE], [SP_FROM], [SP_TO]) VALUES (1, 1, 100, '2016-11-01', '9999-12-31 23:59:59');
GO

-- occorre disabilitare il supporto temporale, rimuovere il periodo,
-- effettuare le modifiche, riaggungere il periodo e riattivare il
-- supporto temporale
--
-- nota: i dati nella tabella di storico sono preservati
BEGIN TRANSACTION;
	ALTER TABLE [SP] SET (SYSTEM_VERSIONING = OFF);
	ALTER TABLE [SP] DROP PERIOD FOR SYSTEM_TIME;
	GO
	INSERT	[HISTORY].[SP_HIST]
	VALUES	(1, 1, 100, '2016-11-01', '2016-11-06')
	,		(1, 1, 101, '2016-11-06', '2016-11-12')
	,		(1, 1, 105, '2016-11-13', '2016-11-15')
	,		(1, 1, 102, '2016-11-16', '2016-11-17')
	,		(1, 1, 150, '2016-11-18', '2016-11-20')
	,		(2, 2, 118, '2016-11-01', '2016-11-19');
	INSERT	[SP]
	VALUES	(1, 1, 104, '2016-11-21', '9999-12-31 23:59:59')
	,		(1, 5, 200, '2016-11-01', '9999-12-31 23:59:59')
	,		(2, 7, 150, '2016-11-01', '9999-12-31 23:59:59')
	,		(2, 2, 120, '2016-11-20', '9999-12-31 23:59:59')
	,		(3, 3, 110, '2016-11-01', '9999-12-31 23:59:59')
	GO
	ALTER TABLE [SP] ADD PERIOD FOR SYSTEM_TIME ([SP_FROM], [SP_TO]);
	ALTER TABLE [SP] ALTER COLUMN [SP_FROM] ADD HIDDEN;
	ALTER TABLE [SP] ALTER COLUMN [SP_TO] ADD HIDDEN;
	ALTER TABLE [SP] SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = HISTORY.SP_HIST));
COMMIT TRANSACTION;
GO
-- verifichiamo i dati inseriti, sono quelli correnti
SELECT *, [SP_FROM], [SP_TO] FROM [SP];
GO

--
-- DEMO 03 modificare e interrogare i dati
--

-- inseriamo un nuovo fornitore e verifichiamo i dati
INSERT	[S] VALUES (5, 'Gilberto',	'Lodi');
GO
SELECT *, [S_FROM], [S_TO] FROM [S];
GO

-- in maniera analoga proviamo ad aggiornare dei dati...
UPDATE [S] SET CITY = 'Leggiuno' WHERE [S#] = 1;
DELETE [S] WHERE [S#] = 4;
GO
-- ... e vediamo solo l'ultima versione considerata vera
SELECT *, [S_FROM], [S_TO] FROM [S];
GO

-- la clausola FOR SYSTEM_TIME si comporta come un predicato
-- che ci permette di spostarci nel tempo e vedere quali
-- proposizioni (righe) erano vere (correnti) al momento specificato
--
-- per esempio AS OF permette di vedere una versione vera in
-- determinato punto nel tempo
-- nota: al momento si possono usare solo literal e variabili :-(
--
DECLARE	@mydate datetime2(0) = DATEADD(second, -60, SYSUTCDATETIME());
SELECT *, [S_FROM], [S_TO] FROM [S] FOR SYSTEM_TIME AS OF @mydate;
GO

-- mentre con ALL si possono vedere tutte le versioni
SELECT *, [S_FROM], [S_TO] FROM [S] FOR SYSTEM_TIME ALL ORDER BY [S#];
GO

-- vediamo il comportamento con un'operazione di JOIN
-- tutti i prodotti correntemente forniti da tutti i fornitori
SELECT	[S].[S#], [S].[NAME], [S].[CITY], [SP].[P#], [SP].[PRICE]
	,	[S].[S_FROM], [S].[S_TO], [SP].[SP_FROM], [SP].[SP_TO]
FROM	[S] JOIN [SP] ON [S].[S#] = [SP].[S#]
ORDER BY [S#];
GO

-- tutti i prodotti forniti da tutti i fornitori al 20 Novembre 2016
-- in questo modo solo una parte dei dati viene considerata alla data specificata
-- (vedi CITY = 'Varese" ma  PRICE del prodotto 1 = 104)
SELECT	[S].[S#], [S].[NAME], [S].[CITY], [SP].[P#], [SP].[PRICE]
	,	[S].[S_FROM], [S].[S_TO], [SP].[SP_FROM], [SP].[SP_TO]
FROM	[S] FOR SYSTEM_TIME AS OF '2016-11-19' JOIN [SP] ON [S].[S#] = [SP].[S#]
ORDER BY [S#], [P#];
GO

-- dovrei specificare una data per entrambe le tabelle
SELECT	[S].[S#], [S].[NAME], [S].[CITY], [SP].[P#], [SP].[PRICE]
	,	[S].[S_FROM], [S].[S_TO], [SP].[SP_FROM], [SP].[SP_TO]
FROM	[S] FOR SYSTEM_TIME AS OF '2016-11-19'
JOIN	[SP] FOR SYSTEM_TIME AS OF '2016-11-19'
  ON	[S].[S#] = [SP].[S#]
ORDER BY [S#], [P#];
GO

-- oppure creare una vista...
DROP VIEW IF EXISTS [S_SP];
GO
CREATE VIEW [S_SP]
AS
	SELECT	[S].[S#], [S].[NAME], [S].[CITY], [SP].[P#], [SP].[PRICE]
		,	[S].[S_FROM], [S].[S_TO], [SP].[SP_FROM], [SP].[SP_TO]
	FROM	[S] JOIN [SP] ON [S].[S#] = [SP].[S#];
GO

-- ... la clausola si applica a tutte le tabelle
SELECT * FROM [S_SP] FOR SYSTEM_TIME AS OF '2016-11-19' ORDER BY [S#], [P#];
GO

-- anche usando OUTER JOIN...
ALTER VIEW [S_SP]
AS
	SELECT	[S].[S#], [S].[NAME], [S].[CITY], [SP].[P#], [SP].[PRICE]
		,	[S].[S_FROM], [S].[S_TO], [SP].[SP_FROM], [SP].[SP_TO]
	FROM	[S] LEFT OUTER JOIN [SP] ON [S].[S#] = [SP].[S#];
GO

-- ... funziona correttamente
SELECT * FROM [S_SP] FOR SYSTEM_TIME AS OF '2016-11-20' ORDER BY [S#]; -- Manca Gilberto
SELECT * FROM [S_SP] ORDER BY [S#];
GO

--
-- Specchietto riassuntivo FOR SYSTEM_TIME
--
-- AS OF     @Time               @SysStartTime <= @Time  AND @SysEndTime > @Time
-- FROM      @Start TO  @End     @SysStartTime <  @End   AND @SysEndTime > @Start
-- BETWEEN   @Start AND @End     @SysStartTime <= @End   AND @SysEndTime > @Start
-- CONTAINED IN (@Start, @End)   @SysStartTime >= @Start AND @SysEndTime <= @End
--
-- esempi (query di riferimento)
SELECT *, [SP_FROM], [SP_TO] FROM [SP] FOR SYSTEM_TIME ALL WHERE [S#] = 1 ORDER BY [S#], [P#], [SP_FROM];
-- FROM...TO *non* include estremo superiore del periodo
SELECT	*, [SP_FROM], [SP_TO]
FROM	[SP] FOR SYSTEM_TIME FROM '2016-11-13' TO '2016-11-16'
WHERE	[S#] = 1;
-- BETWEEN...AND include estremo superiore del periodo
SELECT	*, [SP_FROM], [SP_TO]
FROM	[SP] FOR SYSTEM_TIME BETWEEN '2016-11-13' AND '2016-11-16'
WHERE	[S#] = 1;
GO

-- esempi per CONTAINED periodi di validità completamente inclusi
-- in periodo specificato (estremi dei periodi di validità inclusi)
SELECT *, [SP_FROM], [SP_TO] FROM [SP] FOR SYSTEM_TIME ALL WHERE [S#] = 1 ORDER BY [S#], [P#], [SP_FROM];
-- nessun periodo di validità completamnte incluso
SELECT	*, [SP_FROM], [SP_TO]
FROM	[SP] FOR SYSTEM_TIME CONTAINED IN ('2016-11-07', '2016-11-11')
WHERE	[S#] = 1;
-- un periodo di validità incluso
SELECT	*, [SP_FROM], [SP_TO]
FROM	[SP] FOR SYSTEM_TIME CONTAINED IN ('2016-11-06', '2016-11-13')
WHERE	[S#] = 1;
-- più periodo di validità inclusi
SELECT	*, [SP_FROM], [SP_TO]
FROM	[SP] FOR SYSTEM_TIME CONTAINED IN ('2016-11-05', '2016-11-15')
WHERE	[S#] = 1;
GO

-- esempio avanzato: evidenziare anomalie nei prezzi dei prodotti
WITH [PRICES] AS
(
	SELECT	[S#], [P#], [PRICE], [SP_FROM]
	,		LAG([PRICE], 1) OVER (PARTITION BY [S#], [P#] ORDER BY [SP_FROM]) AS [PREV_PRICE]
	,		LEAD([PRICE], 1) OVER (PARTITION BY [S#], [P#] ORDER BY [SP_FROM]) AS [NEXT_PRICE]
	FROM	[SP] FOR SYSTEM_TIME ALL
)
SELECT	[S#], [P#], [SP_FROM], [PREV_PRICE], [PRICE], [NEXT_PRICE]
FROM	[PRICES]
WHERE	ABS([PREV_PRICE] - [PRICE])/[PREV_PRICE] >= 0.1 AND ABS([NEXT_PRICE] - [PRICE])/[NEXT_PRICE] >= 0.1;
GO

-- se proviamo ad aggiornare un valore della tabella di storico...
UPDATE	[HISTORY].[SP_HIST]
SET		[PRICE] = 105
WHERE	[S#] = 1 AND [P#] = 1 AND [SP_FROM] = '2016-11-18';
GO

-- .... non possiamo, è necessario prima disabilitare il supporto temporale
BEGIN TRANSACTION;
	ALTER TABLE [SP] SET (SYSTEM_VERSIONING = OFF);
	GO
	UPDATE	[HISTORY].[SP_HIST]
	SET		[PRICE] = 105
	WHERE	[S#] = 1 AND [P#] = 1 AND [SP_FROM] = '2016-11-18';
	GO
	ALTER TABLE [SP] SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = HISTORY.SP_HIST));
COMMIT TRANSACTION;

-- non è pratico ma forse stiamo sbagliando andando a modifcare la storia...
-- forse servirebbe una tabella bi-temporale

--
-- DEMO 04: modificare lo schema di una tabella con supporto temporale
--

-- aggiungiamo una colonna per mantenere la quantità di prodotti che
-- il fornitore ha a magazzino, se la colonna non ammette NULL si
-- deve specificare un vincolo DEFAULT
ALTER TABLE [SP] ADD QTY int NULL;
GO

-- verifichiamo i dati sia nella tabella con i dati correnti
-- che in quella con i dati storici
SELECT *, [SP_FROM], [SP_TO] FROM [SP] ORDER BY [S#], [P#], [SP_FROM];
SELECT * FROM [HISTORY].[SP_HIST] ORDER BY [S#], [P#], [SP_FROM];
GO

--
-- DEMO 05: trnasazioni e tabelle con supporto temporale
--

-- aggiorniamo la quantità dei prodotti che i fornitori hanno a magazzino
BEGIN TRANSACTION;
	UPDATE [SP] SET QTY = 3 WHERE [S#] = 1 AND [P#] = 1;
	WAITFOR DELAY '00:00:01';
	UPDATE [SP] SET QTY = 5 WHERE [S#] = 1 AND [P#] = 5;
	WAITFOR DELAY '00:00:01';
	UPDATE [SP] SET QTY = 8 WHERE [S#] = 2 AND [P#] = 2;
	WAITFOR DELAY '00:00:01';
	UPDATE [SP] SET QTY = 6 WHERE [S#] = 2 AND [P#] = 7;
	WAITFOR DELAY '00:00:01';
	UPDATE [SP] SET QTY = 4 WHERE [S#] = 3 AND [P#] = 3;
	WAITFOR DELAY '00:00:01';
COMMIT TRANSACTION;

-- nonostante gli aggiornamenti siano stati fatti a un secondo di
-- distanza, la data di inizio periodo viene impostata per tutte
-- le righe alla data di inizio della transazione
SELECT *, [SP_FROM], [SP_TO] FROM [SP] ORDER BY [S#], [P#], [SP_FROM];
GO

-- alcune conseguenze potrebbero non essere intuitive
-- consideriamo la diminuzione della quantità e la successiva
-- eliminazione della riga in una singola transazione
BEGIN TRANSACTION;
	UPDATE [SP] SET QTY = QTY - 1 WHERE [S#] = 1 AND [P#] = 1;
	UPDATE [SP] SET QTY = QTY - 1 WHERE [S#] = 1 AND [P#] = 1;
	UPDATE [SP] SET QTY = QTY - 1 WHERE [S#] = 1 AND [P#] = 1;
	DELETE [SP] WHERE [S#] = 1 AND [P#] = 1;
COMMIT TRANSACTION;

-- chiedendo la versione corrente non otteniamo nulla perché cancellata
SELECT *, [SP_FROM], [SP_TO] FROM [SP] WHERE [S#] = 1 AND [P#] = 1;

-- chiedendo tutte le versioni otteniamo comunque una visione parziale della
-- riga con il valore all'inizio della transazione
SELECT *, [SP_FROM], [SP_TO] FROM [SP] FOR SYSTEM_TIME ALL WHERE [S#] = 1 AND [P#] = 1;

-- in tutti i casi accedendo alla tabella corrente otteniamo al più l'ultima versione
-- prima degli aggiornamento e della cancellazione
SELECT *, [SP_FROM], [SP_TO] FROM [SP] FOR SYSTEM_TIME AS OF '2016-11-28 23:49:51' WHERE [S#] = 1 AND [P#] = 1;
SELECT *, [SP_FROM], [SP_TO] FROM [SP] FOR SYSTEM_TIME FROM '2016-11-21' TO '2016-11-29' WHERE [S#] = 1 AND [P#] = 1;
SELECT *, [SP_FROM], [SP_TO] FROM [SP] FOR SYSTEM_TIME CONTAINED IN ('2016-11-21', '2016-11-29') WHERE [S#] = 1 AND [P#] = 1;

-- per accedere alle versioni intermedie è necessario accedere direttamente 
-- alla tabella di storico che però non ci permette di discriminare la sequenza
-- delle operazioni
SELECT * FROM [HISTORY].[SP_HIST] WHERE [S#] = 1 AND [P#] = 1 ORDER BY [S#], [P#], [SP_FROM];
GO

-- discriminare quali colonne sono state modificate può essere tedioso...
-- in attesa di una soluzione tipo bitmap possiamo usare un "trucco"
-- utilizzando le nuove funionalità JSON
SELECT	[S_CURR].[key] as [Column], [S_CURR].[value] AS [Current], [S_HIST].[value] AS [Historical]
FROM	OPENJSON((SELECT * FROM [S] WHERE [S#] = 1 FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) AS [S_CURR]
JOIN	OPENJSON((SELECT * FROM [S] FOR SYSTEM_TIME AS OF '2016-11-20' WHERE [S#] = 1 FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) AS [S_HIST]
  ON	[S_CURR].[key] = [S_HIST].[key]
WHERE	[S_CURR].[value] <> [S_HIST].[value];
GO
