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

------------------------------------------------------------------------
-- Estimating Data Compression savings in SQL Server 2019
------------------------------------------------------------------------
USE WideWorldImporters;  
GO  

-- Estimates for all indexes
SELECT	I.index_id, I.name, I.type_desc
FROM	sys.tables AS T
JOIN	sys.indexes AS I
  ON	T.object_id = I.object_id
WHERE	T.schema_id = SCHEMA_ID('Sales') AND T.name = 'InvoiceLines';

EXEC sp_estimate_data_compression_savings 'Sales', 'InvoiceLines', NULL, NULL, 'PAGE';  
EXEC sp_estimate_data_compression_savings 'Sales', 'InvoiceLines', NULL, NULL, 'COLUMNSTORE';  
GO  

-- index 6 (NCCX_Sales_InvoiceLines) is already COLUMNSTORE compressed
-- so let's see if we can gain further with LZH compression
EXEC sp_estimate_data_compression_savings 'Sales', 'InvoiceLines', 6, NULL, 'COLUMNSTORE_ARCHIVE';  
GO 

-----------------------------------------------------------------------
-- Internal pages information
-----------------------------------------------------------------------
USE tempdb;
GO

-- simple usage and mode difference
SELECT * FROM sys.dm_db_page_info (2, 1, 16, 'LIMITED')	-- default
UNION ALL
SELECT * FROM sys.dm_db_page_info (2, 1, 16, 'DETAILED')
GO

CREATE OR ALTER FUNCTION dbo.fn_numbers(@Start AS BIGINT,@End AS BIGINT) RETURNS TABLE
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

-- check different page types getting detailed info
SELECT	P.*
FROM	dbo.fn_numbers(1, 63)
OUTER
APPLY	sys.dm_db_page_info (2, 1, n, 'DETAILED') AS P
GO

-- Practical case to check tempdb contention
-- Stress test case credits to Brent Ozar https://www.brentozar.com/archive/2014/05/tell-need-tempdb-files
USE tempdb;
GO
CREATE PROCEDURE dbo.tempdbstress
AS
SET NOCOUNT ON;
	SELECT TOP(5000) a.name, replicate(a.status,4000) as col2
	INTO #t1
	FROM master..spt_values AS a
	CROSS
	JOIN master..spt_values AS b
	OPTION (MAXDOP 1);
GO

-- Run stress test from command line
-- ostress.exe -Slocalhost -E -dtempdb -Q"exec dbo.tempdbstress" -n8 -r300 -b -q

-- verify page info for requests waiting on pages
SELECT	D.session_id, page_info.* 
FROM	sys.dm_exec_requests AS d  
CROSS APPLY sys.fn_PageResCracker (d.page_resource) AS r  
CROSS APPLY sys.dm_db_page_info(r.db_id, r.file_id, r.page_id, 'DETAILED') AS page_info
GO

-- In most cases I would still use sp_whoisactive first for such scenarios...
exec dbo.sp_whoisactive;
