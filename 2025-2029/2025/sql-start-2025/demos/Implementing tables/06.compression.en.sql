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
-- Credits:     Demos on https://docs.microsoft.com
------------------------------------------------------------------------
USE master;
GO

--
-- Create test database
--
IF EXISTS(SELECT * FROM sys.databases WHERE name = 'CompTest')
BEGIN
	ALTER DATABASE CompTest SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DROP DATABASE CompTest;
END
CREATE DATABASE CompTest;
GO
USE CompTest;
GO

--
-- Demo: vardecimal storage format analysis and activation
--
IF OBJECT_ID('dbo.OrderDetail') IS NOT NULL
	DROP TABLE dbo.OrderDetail;

CREATE TABLE dbo.OrderDetail (
	SalesOrderID		int				NOT NULL
,	SalesOrderDetailID	int				NOT NULL
,	LineTotal			numeric(38, 6)	NOT NULL

,	CONSTRAINT	pk_OrderDetail
	PRIMARY KEY	(SalesOrderID, SalesOrderDetailID)
);
GO

INSERT	dbo.OrderDetail
SELECT	O.SalesOrderID, O.SalesOrderDetailID, O.LineTotal
FROM	AdventureWorks2008R2.Sales.SalesOrderDetail AS O
GO

-- check pages allocation (510)
SELECT	*
FROM	sys.allocation_units	AS A1
JOIN	sys.partitions			AS P1
  ON	A1.container_id = P1.partition_id
WHERE	P1.object_id = OBJECT_ID('dbo.OrderDetail');
GO

-- show space savings estimates 21.6 variable vs. 32 fixed
EXEC	sp_estimated_rowsize_reduction_for_vardecimal 'dbo.OrderDetail';
GO

-- enable vardecimal at database level for SQL Server 2005 SP2
-- (not needed on SQL Server 2008, on by default)
-- (execute without parameters to show status)
EXEC	sp_db_vardecimal_storage_format 'CompTest', 'ON';
GO

-- enable vardecimal at table level
EXEC	sp_tableoption 'dbo.OrderDetail', 'vardecimal storage format', 1;
GO

-- check again pages allocation (374 vs 510)
SELECT	*
FROM	sys.allocation_units	AS A1
JOIN	sys.partitions			AS P1
  ON	A1.container_id = P1.partition_id
WHERE	P1.object_id = OBJECT_ID('dbo.OrderDetail');
GO

--
-- Demo: 8060 bytes for uncompressed still enforced
--
IF OBJECT_ID('dbo.CompressTest_1') IS NOT NULL
	DROP TABLE dbo.CompressTest_1;
GO

CREATE TABLE dbo.CompressTest_1 (					-- Row overhead = row header + NULL bitmap = 4 + 3 = 7
	EntityID			int				NOT NULL	-- + 4 bytes	=   11 bytes
,	Filler				char(8000)		NOT NULL	-- + 8000 bytes = 8011 bytes
,	EntityQty_01		numeric(38)		NOT NULL	-- + 17 bytes	= 8028 bytes
,	EntityQty_02		numeric(38)		NOT NULL	-- + 17 bytes	= 8045 bytes

,	CONSTRAINT	pk_CompressTest_1
	PRIMARY KEY	(EntityID)
);
GO
--EXEC	sp_estimated_rowsize_reduction_for_vardecimal 'dbo.CompressTest_1';

-- enable vardecimal at table level
EXEC	sp_tableoption 'dbo.CompressTest_1', 'vardecimal storage format', 1;
GO

-- If we try to add a new column it fails because the row size would exceed 8060
ALTER TABLE dbo.CompressTest_1
ADD EntityQty_03 numeric(38) NULL;
GO

-- we can still add new columns if they fit, for example numeric(9) is 5 + 2 bytes
ALTER TABLE dbo.CompressTest_1
ADD EntityQty_03 numeric(9) NULL;
GO

--
-- Demo: row compression analysis and activation
--
-- original format:		510 pages
-- vardecimal format:	374 pages
--
IF OBJECT_ID('dbo.OrderDetail') IS NOT NULL
	DROP TABLE dbo.OrderDetail;

CREATE TABLE dbo.OrderDetail (
	SalesOrderID		int				NOT NULL
,	SalesOrderDetailID	int				NOT NULL
,	LineTotal			numeric(38, 6)	NOT NULL

,	CONSTRAINT	pk_OrderDetail
	PRIMARY KEY	(SalesOrderID, SalesOrderDetailID)
);
GO

INSERT	dbo.OrderDetail
SELECT	O.SalesOrderID, O.SalesOrderDetailID, O.LineTotal
FROM	AdventureWorks2008R2.Sales.SalesOrderDetail AS O
GO

EXEC sp_estimate_data_compression_savings 'dbo', 'OrderDetail', NULL, NULL, 'ROW';
GO

ALTER TABLE	dbo.OrderDetail 
REBUILD WITH (DATA_COMPRESSION = ROW);
GO

-- check again pages allocation (235 vs 510)
SELECT	*
FROM	sys.allocation_units	AS A1
JOIN	sys.partitions			AS P1
  ON	A1.container_id = P1.partition_id
WHERE	P1.object_id = OBJECT_ID('dbo.OrderDetail');
GO

EXEC sp_estimate_data_compression_savings 'dbo', 'OrderDetail', NULL, NULL, 'PAGE';
GO

ALTER TABLE	dbo.OrderDetail 
REBUILD WITH (DATA_COMPRESSION = PAGE);
GO

-- check again pages allocation (190 vs 510 makes)
SELECT	*
FROM	sys.allocation_units	AS A1
JOIN	sys.partitions			AS P1
  ON	A1.container_id = P1.partition_id
WHERE	P1.object_id = OBJECT_ID('dbo.OrderDetail');
GO

-- To recap:
--
-- original format:		510 pages
-- vardecimal format:	374 pages
-- row compression:		235 pages
-- page compression:	190 pages

------------------------------------------------------------------------
-- SQL Server 2016+ COMPRESS(), DECOMPRESS()
------------------------------------------------------------------------
USE tempdb;
GO

-- Verify that Product diagrams are in XML
SELECT * FROM	AdventureWorks2012.Production.Illustration;
GO

-- Copy product illustration table compressing diagrams
-- Note: XML type is not supported directly
IF OBJECT_ID('tempdb..#tmp_compressed') IS NOT NULL
	DROP TABLE #tmp_compressed;

SELECT
	IllustrationID
,	COMPRESS(CAST(Diagram AS nvarchar(max))) AS Diagram
,	ModifiedDate
INTO	#tmp_compressed
FROM	AdventureWorks2012.Production.Illustration;
GO

-- Look at table metadata: column is now varbinary(max)
EXEC sp_help '#tmp_compressed';
GO

-- Verify that Product diagrams are no more XML
SELECT * FROM #tmp_compressed;
GO

-- Check space saving in bytes
SELECT
	I1.IllustrationID
,	DATALENGTH(I1.Diagram) AS OriginalDiagramSize
,	DATALENGTH(I2.Diagram) AS CompressedDiagramSize
,	DATALENGTH(I1.Diagram) - DATALENGTH(I2.Diagram) AS SizeDelta
FROM	AdventureWorks2012.Production.Illustration AS I1
JOIN	#tmp_compressed AS I2
  ON	I1.IllustrationID = I2.IllustrationID;
GO

-- Verify decompressed data
SELECT	CAST(DECOMPRESS(Diagram) AS xml)AS Diagram
FROM	#tmp_compressed
WHERE	IllustrationID = 5	
GO
