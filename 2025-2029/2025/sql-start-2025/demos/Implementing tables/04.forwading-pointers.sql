------------------------------------------------------------------------
-- Copyright:   2019 Gianluca Hotz
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
-- This script shows how forwarded records in a heap can increase I/O
-- and how ALTER TABLE … REBUILD removes them.
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Setup demo
------------------------------------------------------------------------
USE tempdb;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.DemoHeap','U') IS NOT NULL
    DROP TABLE dbo.DemoHeap;
GO

CREATE TABLE dbo.DemoHeap
(
    ID        int IDENTITY(1,1) NOT NULL,
    ShortCol  char(10)       NOT NULL,
    LongCol   varchar(8000)  NULL
);
GO

-- Insert 1 milion rows
;WITH cte AS
(
    SELECT TOP (1000000)
           ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.DemoHeap (ShortCol)
SELECT 'short' FROM cte;
GO

-- Create nonclustered index
CREATE NONCLUSTERED INDEX IX_DemoHeap_ShortCol
    ON dbo.DemoHeap (ShortCol);
GO

------------------------------------------------------------------------
-- Baseline: I/O & forwarded-row count
-- (2841 logical reads, CPU time = 265 ms,  elapsed time = 261 ms)
------------------------------------------------------------------------
PRINT 'Baseline (no forwarded rows)';

DBCC DROPCLEANBUFFERS;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SELECT  COUNT(*) AS num_rows                -- this alone would just use the non clustered index 
    ,   SUM(LEN(LongCol)) AS total_lenght   -- this forces the lookup of the rows
FROM    dbo.DemoHeap
WHERE   ShortCol = 'short';
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

SELECT  SUM(forwarded_record_count) AS forwarded_before
FROM    sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.DemoHeap'), NULL, NULL, 'DETAILED');
GO

------------------------------------------------------------------------
-- Workload: expand 50 % of rows
------------------------------------------------------------------------
UPDATE TOP (50) PERCENT dbo.DemoHeap
SET    LongCol = REPLICATE('x',4000)
WHERE  LongCol IS NULL;
GO  -- introduces ~500 000 forwarded records

------------------------------------------------------------------------
-- After updates: I/O & forwarded‑row count
-- (750717 logical reads, CPU time = 2046 ms,  elapsed time = 441 ms.)
------------------------------------------------------------------------
PRINT 'After updates (forwarded rows present)';

DBCC DROPCLEANBUFFERS;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SELECT  COUNT(*) AS num_rows 
    ,   SUM(LEN(LongCol)) AS total_lenght
FROM    dbo.DemoHeap
WHERE   ShortCol = 'short';
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

SELECT  SUM(forwarded_record_count) AS forwarded_after_growth
FROM    sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.DemoHeap'), NULL, NULL, 'DETAILED');
GO

------------------------------------------------------------------------
-- Fix: heap rebuild
------------------------------------------------------------------------
ALTER TABLE dbo.DemoHeap REBUILD;
GO

------------------------------------------------------------------------
-- Post‑rebuild: I/O & forwarded‑row count
-- (251424 logical reads,  CPU time = 1016 ms,  elapsed time = 134 ms.)
------------------------------------------------------------------------
PRINT 'After heap rebuild (forwarded rows removed)';

DBCC DROPCLEANBUFFERS;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SELECT  COUNT(*) AS num_rows 
    ,   SUM(LEN(LongCol)) AS total_lenght
FROM    dbo.DemoHeap
WHERE   ShortCol = 'short';
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

SELECT  SUM(forwarded_record_count) AS forwarded_after_rebuild
FROM    sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.DemoHeap'), NULL, NULL, 'DETAILED');
GO

------------------------------------------------------------------------
-- Clean‑up
------------------------------------------------------------------------
-- DROP TABLE dbo.DemoHeap;
-- GO
