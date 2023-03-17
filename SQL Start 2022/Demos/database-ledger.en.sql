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

------------------------------------------------------------------------
-- Activate Ledger for all new tables in a database
------------------------------------------------------------------------
-- CREATE DATABASE [lgdemo] WITH LEDGER = ON;

-- By default new tables are created as updatable

-- Trying to create a table with LEDGER = OFF results in the following error
-- Msg 37420, Level 16, State 1, Line 5
-- LEDGER = OFF cannot be specified for tables in databases that were created with LEDGER = ON.

-- Can't turn the option OFF

------------------------------------------------------------------------
-- Creation of an updatable Ledger Table
------------------------------------------------------------------------
USE lgdemo;
GO
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

-- Let's insert a row in a first transaction
INSERT INTO [Account].[Balance]
VALUES (1, 'Jones', 'Nick', 50);
GO

-- Then we insert another 3 rows in a second transaction
INSERT INTO [Account].[Balance]
VALUES
	(2, 'Smith', 'John', 500)
,	(3, 'Smith', 'Joe', 30)
,	(4, 'Michaels', 'Mary', 200);
GO

-- By default, columns with information relating to transactions are
-- not returned (provides transparency to applications using *)
SELECT	* 
FROM	[Account].[Balance];
GO

-- Metadata columns must be explicitly selected
SELECT
	* 
,	[ledger_start_transaction_id]
,	[ledger_end_transaction_id]
,	[ledger_start_sequence_number]
,	[ledger_end_sequence_number]
FROM [Account].[Balance];
GO
-- Note: two transaction_id, sequence_number relative to transaction_id

-- Let's update the balance of customer 1
UPDATE	[Account].[Balance]
SET		[Balance] = 100
WHERE	[CustomerID] = 1;
GO

-- Schema metadata for history table and ledger view
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

-- We query the updateable table, the history table and the ledger view
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
-- Creation of an append-only Ledger Table
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

-- Insert a row
INSERT INTO [AccessControl].[KeyCardEvents]
VALUES ('43869', 'Building42', '2020-05-02T19:58:47.1234567');
GO

-- Query ledger transaction metadata
SELECT *
,	[ledger_start_transaction_id]
,	[ledger_start_sequence_number]
FROM [AccessControl].[KeyCardEvents];
GO

-- If we try to update, it gives an error
UPDATE [AccessControl].[KeyCardEvents]
SET		[EmployeeID] = 34184
WHERE	[EmployeeID] = 43869;
GO

-- Other operations that are allowed
EXEC sp_rename 'AccessControl.KeyCardEvents', 'KeyCardEvents2';
GO

DROP TABLE [AccessControl].[KeyCardEvents2];
GO

-- can't drop dropped ledger table :-)
DROP TABLE [AccessControl].[MSSQL_DroppedLedgerTable_KeyCardEvents2_6A1C3C92ED49410288FFF44EFC3DC774];
GO

------------------------------------------------------------------------
-- System tables database Ledger
------------------------------------------------------------------------
SELECT * FROM sys.database_ledger_transactions
GO

SELECT * FROM sys.database_ledger_blocks
GO

------------------------------------------------------------------------
-- Digest verification with automatic saving
------------------------------------------------------------------------
-- Copy code from Azure portal

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
-- Digest verification with manual saving
------------------------------------------------------------------------
-- Manually generate digest and save it in an immutable, trusted storage
EXEC sp_generate_database_ledger_digest;
GO

-- when it needs to be checked, pass it directly to the system procedure
EXEC sp_verify_database_ledger N'
{"database_name":"lgdemo01","block_id":6,"hash":"0xBE41684AADFCA2E9163F1587569F5CE297E014410EB7B2D6E76DC4DE3A3939B8","last_transaction_commit_time":"2022-06-09T22:49:40.0333333","digest_time":"2022-06-09T22:59:18.3039187"}
';
GO

------------------------------------------------------------------------
-- Data tampering example (requires on-premises SQL Server 2022+)
------------------------------------------------------------------------
CREATE DATABASE lgdemo;
GO
-- Snapshot Isolation is needed to run the verification procedure
ALTER DATABASE [lgdemo] SET ALLOW_SNAPSHOT_ISOLATION ON;
GO
USE lgdemo;
GO
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
INSERT INTO [AccessControl].[KeyCardEvents]
VALUES ('43869', 'Building42', '2020-05-02T19:58:47.1234567');
GO

-- Manually generate digest and save it in an immutable, trusted storage
EXEC sp_generate_database_ledger_digest;
GO

-- Verify the database
EXEC sp_verify_database_ledger N'
{"database_name":"lgdemo","block_id":0,"hash":"0x12B81D1A366CCD947495643C1D4E9E23FDBB79ECACDF12F9C53EEBECC952E95B","last_transaction_commit_time":"2022-06-09T16:47:24.9366667","digest_time":"2022-06-09T23:47:36.5756704"}
';

-- Trying to update fails...
UPDATE	[AccessControl].[KeyCardEvents]
SET		[Timestamp] = '2020-05-02T18:58:47.1234567'
WHERE	[EmployeeID] = 43870;
GO

-- But the smart DBA knows how to use unofficial code to work around
SELECT	DB_ID() AS database_id
,		sys.fn_PhysLocFormatter(%%physloc%%) AS PageId
,		[TimeStamp]
,		SUBSTRING(CAST(CAST('2020-05-02T18:58:47.1234567' as datetime2) AS varbinary), 3, 8) AS Tampered_Timestamp_Hex
FROM	[AccessControl].[KeyCardEvents]
WHERE	[EmployeeID] = 43870;
GO

-- DBCC PAGE ( {'dbname' | dbid}, filenum, pagenum [, printopt={0|1|2|3} ])
DBCC TRACEON(3604) WITH NO_INFOMSGS;
DBCC PAGE (5, 1, 360, 2) WITH NO_INFOMSGS;
GO
-- DBCC WRITEPAGE ({'dbname' | dbid}, fileid, pageid, {offset | 'fieldname'}, length, data [, directORbufferpool])
DBCC WRITEPAGE (5, 1, 360, 105, 7, 0xA423169F0A410B) WITH NO_INFOMSGS;
GO

-- Tampering done!
SELECT	*
FROM	[AccessControl].[KeyCardEvents]
WHERE	[EmployeeID] = 43870;
GO

-- But digest verification fails!
EXEC sp_verify_database_ledger N'
{"database_name":"lgdemo","block_id":0,"hash":"0x12B81D1A366CCD947495643C1D4E9E23FDBB79ECACDF12F9C53EEBECC952E95B","last_transaction_commit_time":"2022-06-09T16:47:24.9366667","digest_time":"2022-06-09T23:47:36.5756704"}
';
