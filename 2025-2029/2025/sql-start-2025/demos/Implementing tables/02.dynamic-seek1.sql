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
SELECT skey FROM dbo.TestTable WHERE pkey = 100;
GO

-- clean procedure cache and buffer cache
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
DBCC DROPCLEANBUFFERS;
GO

-- run the query with including "actual execution plan" or use SET SHOWPLAN_TEXT ON/OFF before/after
-- note: time/IO statistics include plan generation and sending, measure them also without including plan
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
DECLARE	@skey	nvarchar(32) = N'737835535';
SELECT skey, pkey, payload FROM dbo.TestTable WHERE skey = @skey ORDER BY pkey;
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

--StmtText
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--  |--Sort(ORDER BY:([TestDS].[dbo].[TestTable].[pkey] ASC))
--       |--Nested Loops(Inner Join, OUTER REFERENCES:([TestDS].[dbo].[TestTable].[pkey]))
--            |--Index Scan(OBJECT:([TestDS].[dbo].[TestTable].[ix_TestTable]),  WHERE:(CONVERT_IMPLICIT(nvarchar(22),[TestDS].[dbo].[TestTable].[skey],0)=CONVERT_IMPLICIT(nvarchar(32),[@skey],0)))
--            |--Clustered Index Seek(OBJECT:([TestDS].[dbo].[TestTable].[PK__TestTabl__40A62DB9BD00E2BF]), SEEK:([TestDS].[dbo].[TestTable].[pkey]=[TestDS].[dbo].[TestTable].[pkey]) LOOKUP ORDERED FORWARD)
--
--Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
--Table 'TestTable'. Scan count 1, logical reads 526, physical reads 2, page server reads 0, read-ahead reads 533, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
--
--SQL Server Execution Times:
--  CPU time = 16 ms,  elapsed time = 16 ms.
--
-- Memory Grant: 1024KB

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
SELECT skey FROM dbo.TestTable WHERE pkey = 100;
GO

-- clean procedure cache and buffer cache
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
DBCC DROPCLEANBUFFERS;
GO

-- run the query with including "actual execution plan" or use SET SHOWPLAN_TEXT ON/OFF before/after
-- note: time/IO statistics include plan generation and sending, measure them also without including plan
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
DECLARE	@skey	nvarchar(32) = N'946195541';
SELECT skey, pkey, payload FROM dbo.TestTable WHERE skey = @skey ORDER BY pkey;
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

--StmtText
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--  |--Sort(ORDER BY:([TestDS].[dbo].[TestTable].[pkey] ASC))
--       |--Nested Loops(Inner Join, OUTER REFERENCES:([TestDS].[dbo].[TestTable].[pkey]))
--            |--Nested Loops(Inner Join, OUTER REFERENCES:([Expr1005], [Expr1006], [Expr1004]))
--            |    |--Compute Scalar(DEFINE:(([Expr1005],[Expr1006],[Expr1004])=GetRangeThroughConvert(CONVERT_IMPLICIT(nvarchar(32),[@skey],0),CONVERT_IMPLICIT(nvarchar(32),[@skey],0),(62))))
--            |    |    |--Constant Scan
--            |    |--Index Seek(OBJECT:([TestDS].[dbo].[TestTable].[ix_TestTable]), SEEK:([TestDS].[dbo].[TestTable].[skey] > [Expr1005] AND [TestDS].[dbo].[TestTable].[skey] < [Expr1006]),  WHERE:(CONVERT_IMPLICIT(nvarchar(22),[TestDS].[dbo].[TestTable].[s
--            |--Clustered Index Seek(OBJECT:([TestDS].[dbo].[TestTable].[PK__TestTabl__40A62DB9E39DDB73]), SEEK:([TestDS].[dbo].[TestTable].[pkey]=[TestDS].[dbo].[TestTable].[pkey]) LOOKUP ORDERED FORWARD)
--
--Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
--Table 'TestTable'. Scan count 1, logical reads 6, physical reads 3, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
--
--SQL Server Execution Times:
--  CPU time = 0 ms,  elapsed time = 0 ms.
--
--Memory Grant: 1024KB

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
SELECT skey FROM dbo.TestTable WHERE pkey = 100;
GO

-- clean procedure cache and buffer cache
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
DBCC DROPCLEANBUFFERS;
GO

-- run the query with including "actual execution plan" or use SET SHOWPLAN_TEXT ON/OFF before/after
-- note: time/IO statistics include plan generation and sending, measure them also without including plan
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
DECLARE	@skey	varchar(32) = '946195541';
SELECT skey, pkey, payload FROM dbo.TestTable WHERE skey = @skey ORDER BY pkey;
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

--StmtText
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--  |--Nested Loops(Inner Join, OUTER REFERENCES:([TestDS].[dbo].[TestTable].[pkey]))
--       |--Index Seek(OBJECT:([TestDS].[dbo].[TestTable].[ix_TestTable]), SEEK:([TestDS].[dbo].[TestTable].[skey]=CONVERT_IMPLICIT(varchar(32),[@skey],0)) ORDERED FORWARD)
--       |--Clustered Index Seek(OBJECT:([TestDS].[dbo].[TestTable].[PK__TestTabl__40A62DB97B11332E]), SEEK:([TestDS].[dbo].[TestTable].[pkey]=[TestDS].[dbo].[TestTable].[pkey]) LOOKUP ORDERED FORWARD)
--
--Table 'TestTable'. Scan count 1, logical reads 6, physical reads 1, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
--
--SQL Server Execution Times:
--   CPU time = 0 ms,  elapsed time = 0 ms.
--
--Memory Grant: 0

