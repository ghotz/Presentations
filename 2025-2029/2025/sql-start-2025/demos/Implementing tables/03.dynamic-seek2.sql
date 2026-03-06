------------------------------------------------------------------------
-- Test Dynamic Search
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Create test database
------------------------------------------------------------------------
USE master;
GO
DROP DATABASE TestDS;
GO
CREATE DATABASE TestDS;
GO
ALTER DATABASE TestDS SET RECOVERY SIMPLE;
GO
USE TestDS;
GO
------------------------------------------------------------------------
-- Create helper function(s)
------------------------------------------------------------------------
DROP FUNCTION IF EXISTS dbo.fn_numbers;
GO
CREATE FUNCTION dbo.fn_numbers(@Start AS BIGINT,@End AS BIGINT) RETURNS TABLE
AS
RETURN
  WITH
  L0   AS(SELECT 1 AS c UNION ALL SELECT 1),
  L1   AS(SELECT 1 AS c FROM L0 AS A, L0 AS B),
  L2   AS(SELECT 1 AS c FROM L1 AS A, L1 AS B),
  L3   AS(SELECT 1 AS c FROM L2 AS A, L2 AS B),
  L4   AS(SELECT 1 AS c FROM L3 AS A, L3 AS B),
  L5   AS(SELECT 1 AS c FROM L4 AS A, L4 AS B),
  Nums AS(SELECT ROW_NUMBER() OVER(ORDER BY c) AS n FROM L5)
  SELECT n FROM Nums 
  WHERE n between  @Start and @End;  
GO

------------------------------------------------------------------------
------------------------------------------------------------------------
-- First test case with SQL Collation
-- SQL_Latin1_General_CP1_CI_AS or SQL_Latin1_General_CP1_CI_AI
------------------------------------------------------------------------
------------------------------------------------------------------------
-- create schema
DROP TABLE IF EXISTS dbo.TestTable;
CREATE TABLE dbo.TestTable (
	pkey	bigint			NOT NULL PRIMARY KEY
,	skey	varchar(22)		COLLATE SQL_Latin1_General_CP1_CI_AI NOT NULL
,	payload	varchar(max)	NOT NULL
);
GO

-- generate test data
DECLARE	@rows bigint = 150000
DECLARE	@payload_len int = 1000;

INSERT	dbo.TestTable (pkey, skey, payload)
SELECT	n AS pkey
	,	CAST(ABS(CHECKSUM(NEWID())) % 10000000000000 AS varchar) AS skey
	,	REPLICATE('P', @payload_len) AS payload
FROM	dbo.fn_numbers(1, @rows);
GO

-- create index
CREATE INDEX ix_TestTable ON dbo.TestTable(skey);
GO

-- get a random skey to search
SELECT skey FROM dbo.TestTable WHERE pkey IN (100, 101);
GO

-- clean procedure cache and buffer cache
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
DBCC DROPCLEANBUFFERS;
GO

-- run the query with including "actual execution plan" or use SET SHOWPLAN_TEXT ON/OFF before/after
-- note: time/IO statistics include plan generation and sending, measure them also without including plan
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
DECLARE	@skey1	nvarchar(32) = N'2112798565';
DECLARE	@skey2	nvarchar(32) = N'1922068831';
SELECT skey, pkey, payload FROM dbo.TestTable WHERE skey IN(@skey1, @skey2) ORDER BY pkey;
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

------------------------------------------------------------------------
------------------------------------------------------------------------
-- Second test case with Windows Collation
-- Latin1_General_100_CI_AS_SC is the closest to SQL_Latin1_General_CP1_CI_AS
-- Latin1_General_100_CI_AI_SC is the closest to SQL_Latin1_General_CP1_CI_AI
------------------------------------------------------------------------
------------------------------------------------------------------------
-- create schema
DROP TABLE IF EXISTS dbo.TestTable;
CREATE TABLE dbo.TestTable (
	pkey	bigint			NOT NULL PRIMARY KEY
,	skey	varchar(22)		COLLATE Latin1_General_100_CI_AI_SC NOT NULL
,	payload	varchar(max)	NOT NULL
);
GO

-- generate test data
DECLARE	@rows bigint = 150000
DECLARE	@payload_len int = 1000;

INSERT	dbo.TestTable (pkey, skey, payload)
SELECT	n AS pkey
	,	CAST(ABS(CHECKSUM(NEWID())) % 10000000000000 AS varchar) AS skey
	,	REPLICATE('P', @payload_len) AS payload
FROM	dbo.fn_numbers(1, @rows);
GO

-- create index
CREATE INDEX ix_TestTable ON dbo.TestTable(skey);
GO

-- get a random skey to search
SELECT skey FROM dbo.TestTable WHERE pkey IN (100, 101);
GO

-- clean procedure cache and buffer cache
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
DBCC DROPCLEANBUFFERS;
GO

-- run the query with including "actual execution plan" or use SET SHOWPLAN_TEXT ON/OFF before/after
-- note: time/IO statistics include plan generation and sending, measure them also without including plan
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
DECLARE	@skey1	nvarchar(32) = N'594748541';
DECLARE	@skey2	nvarchar(32) = N'1081820051';
SELECT skey, pkey, payload FROM dbo.TestTable WHERE skey IN(@skey1, @skey2) ORDER BY pkey;
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

------------------------------------------------------------------------
------------------------------------------------------------------------
-- Third test case with SQL Collation and correct parameter type
------------------------------------------------------------------------
------------------------------------------------------------------------
-- create schema
DROP TABLE IF EXISTS dbo.TestTable;
CREATE TABLE dbo.TestTable (
	pkey	bigint			NOT NULL PRIMARY KEY
,	skey	varchar(22)		COLLATE SQL_Latin1_General_CP1_CI_AI NOT NULL
,	payload	varchar(max)	NOT NULL
);
GO

-- generate test data
DECLARE	@rows bigint = 150000
DECLARE	@payload_len int = 1000;

INSERT	dbo.TestTable (pkey, skey, payload)
SELECT	n AS pkey
	,	CAST(ABS(CHECKSUM(NEWID())) % 10000000000000 AS varchar) AS skey
	,	REPLICATE('P', @payload_len) AS payload
FROM	dbo.fn_numbers(1, @rows);
GO

-- create index
CREATE INDEX ix_TestTable ON dbo.TestTable(skey);
GO

-- get a random skey to search
SELECT skey FROM dbo.TestTable WHERE pkey IN (100, 101);
GO

-- clean procedure cache and buffer cache
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
DBCC DROPCLEANBUFFERS;
GO

-- run the query with including "actual execution plan" or use SET SHOWPLAN_TEXT ON/OFF before/after
-- note: time/IO statistics include plan generation and sending, measure them also without including plan
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
DECLARE	@skey1	varchar(32) = N'591304387';
DECLARE	@skey2	varchar(32) = N'2088131487';
SELECT skey, pkey, payload FROM dbo.TestTable WHERE skey IN(@skey1, @skey2) ORDER BY pkey;
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

