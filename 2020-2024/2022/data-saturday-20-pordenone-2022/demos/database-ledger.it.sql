------------------------------------------------------------------------
-- Copyright:   2021 Gianluca Hotz
-- License:     MIT License
--              Permission is hereby granted, free of charge, to any
--              person obtaining a copy of this software and associated
--              documentation files (the "Software"), to deal in the
--              Software without restriction, including without
--              limitation the rights to use, copy, modify, merge,
--              publish, distribute, sublicense, and/or sell copies of
--              the Software, and to permit persons to whom the
--              Software is furnished to do so, subject to the
--              following conditions:
--              The above copyright notice and this permission notice
--              shall be included in all copies or substantial portions
--              of the Software.
--              THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
--              ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
--              LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
--              FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
--              EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
--              FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
--              AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--              OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
--              OTHER DEALINGS IN THE SOFTWARE.
-- Credits:
------------------------------------------------------------------------

-- Attivazione Ledger per tutte le nuove tabelle
-- CREATE DATABASE [lgdemo] WITH LEDGER = ON;

------------------------------------------------------------------------
-- Creazione di una tabella aggiornabile (Updatable Ledger Table)
------------------------------------------------------------------------
CREATE SCHEMA [Account];
GO
CREATE TABLE [Account].[Balance]
(
	[CustomerID]	int				NOT NULL PRIMARY KEY CLUSTERED
,	[LastName]		varchar(50)		NOT NULL
,	[FirstName]		varchar(50)		NOT NULL
,	[Balance]		decimal(10,2)	NOT NULL
)
WITH (
	SYSTEM_VERSIONING = ON	--(HISTORY_TABLE = [Account].[BalanceHistory])
,	LEDGER = ON				--(LEDGER_VIEW = [Account].[BalanceLedgerView])
);
GO

-- Inseriamo una riga in una prima transazione
INSERT INTO [Account].[Balance]
VALUES (1, 'Jones', 'Nick', 50);
GO

-- Inseriamo tre righe in una seconda transazione
INSERT INTO [Account].[Balance]
VALUES
	(2, 'Smith', 'John', 500)
,	(3, 'Smith', 'Joe', 30)
,	(4, 'Michaels', 'Mary', 200);
GO

-- Di default le colonne con le informazioni relative alle
-- transazioni non vengono tornate (trasparente applicazioni)
SELECT * 
FROM [Account].[Balance];
GO

-- Devono essere selezionate esplicitamente
SELECT * 
,	[ledger_start_transaction_id]
,	[ledger_end_transaction_id]
,	[ledger_start_sequence_number]
,	[ledger_end_sequence_number]
FROM [Account].[Balance];
GO
-- 2 transaction_id, sequence number relativo a transaction_id

-- Aggiorniamo il bilancio del cliente 1 
UPDATE	[Account].[Balance]
SET		[Balance] = 100
WHERE	[CustomerID] = 1;
GO

-- Metadata tabella e vista
SELECT 
	ts.[name] + '.' + t.[name] AS [ledger_table_name]
,	hs.[name] + '.' + h.[name] AS [history_table_name]
,	vs.[name] + '.' + v.[name] AS [ledger_view_name]
FROM sys.tables AS t
JOIN sys.tables AS h ON (h.[object_id] = t.[history_table_id])
JOIN sys.views v ON (v.[object_id] = t.[ledger_view_id])
JOIN sys.schemas ts ON (ts.[schema_id] = t.[schema_id])
JOIN sys.schemas hs ON (hs.[schema_id] = h.[schema_id])
JOIN sys.schemas vs ON (vs.[schema_id] = v.[schema_id]);
GO

-- Interroghiamo la tabella aggiornabile, quella di storico e la vista
SELECT * 
,	[ledger_start_transaction_id]
,	[ledger_end_transaction_id]
,	[ledger_start_sequence_number]
,	[ledger_end_sequence_number]
FROM [Account].[Balance];

SELECT * FROM [Account].[MSSQL_LedgerHistoryFor_1525580473];

SELECT *
FROM [Account].[Balance_Ledger]
ORDER BY [ledger_transaction_id]
GO

------------------------------------------------------------------------
-- Creazione di una tabella solo accodamento (Append-only Ledger Table)
------------------------------------------------------------------------
CREATE SCHEMA [AccessControl];
GO
CREATE TABLE [AccessControl].[KeyCardEvents]
(
	[EmployeeID]					INT				NOT NULL PRIMARY KEY CLUSTERED
,	[AccessOperationDescription]	NVARCHAR(MAX)	NOT NULL
,	[Timestamp]						Datetime2		NOT NULL
)
WITH (
	LEDGER = ON (APPEND_ONLY = ON)
);
GO

-- Inseriamo una prima riga
INSERT INTO [AccessControl].[KeyCardEvents]
VALUES ('43869', 'Building42', '2020-05-02T19:58:47.1234567');
GO

-- Interroghiamo la tabella con le info sulle transazioni
SELECT *
,	[ledger_start_transaction_id]
,	[ledger_start_sequence_number]
FROM [AccessControl].[KeyCardEvents];
GO

-- Se proviamo a fare un'aggiornamento, da errore
UPDATE [AccessControl].[KeyCardEvents]
SET		[EmployeeID] = 34184
WHERE	[EmployeeID] = 43869;
GO

-- altre operazioni che ora si possono fare
EXEC sp_rename 'AccessControl.KeyCardEvents', 'KeyCardEvents2';
GO

------------------------------------------------------------------------
-- Tabella di sistema Ledger
------------------------------------------------------------------------
SELECT * FROM sys.database_ledger_transactions
GO

SELECT * FROM sys.database_ledger_blocks
GO

------------------------------------------------------------------------
-- Verifica Digest con salvataggio automatico
------------------------------------------------------------------------
-- Copiare codice da portale Azure

DECLARE @digest_locations NVARCHAR(MAX) = (SELECT * FROM sys.database_ledger_digest_locations FOR JSON AUTO, INCLUDE_NULL_VALUES);
SELECT @digest_locations as digest_locations;
BEGIN TRY
    EXEC sys.sp_verify_database_ledger_from_digest_storage @digest_locations;
SELECT 'Ledger verification succeeded.' AS Result;
END TRY
BEGIN CATCH
    THROW;
END CATCH

------------------------------------------------------------------------
-- Verifica Digest con salvataggio manuale
------------------------------------------------------------------------
-- genero manualmente il digest e lo salvo in uno storage immutabile di mia fiducia
EXEC sp_generate_database_ledger_digest;
GO

-- quando devo verificare lo passo direttamente alla procedura di sistema
EXEC sp_verify_database_ledger N'
{"database_name":"lgdemo2","block_id":6,"hash":"0x2B17C29A0A801C9878633A472B2CF2E433905863062379D79D6521AF1A181F15","last_transaction_commit_time":"2022-02-25T22:59:22.0733333","digest_time":"2022-02-25T23:11:04.9436931"}
';
GO

-- Esempio di integrazione con Azure Confidential Ledger
-- https://docs.microsoft.com/en-us/azure/azure-sql/database/ledger-how-to-access-acl-digest
