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
-- Credits:     Davide Mauri
------------------------------------------------------------------------
USE AdventureWorks2017;
GO

------------------------------------------------------------------------
-- Access methods (show execution plan)
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Heap Table Scan
------------------------------------------------------------------------
-- Note: there's no info about allocation-order usage, but for a HEAP
-- Allocation-Order Scan mode is the only available method
SELECT DatabaseLogId, PostTime FROM dbo.DatabaseLog;
GO

------------------------------------------------------------------------
-- Unordered Clustered Index Scan (full) allocation-order
------------------------------------------------------------------------
-- Note: there's also no info about allocation-order vs index-order
-- physical access methods, a practical way (without generating stack
-- dumps) is to be sure pre-requisites are met and compare the I/O
-- characteristic without pre-requisites

-- > 64 pages, NOLOCK and no ORDER BY ensure allocation-order usage
DBCC DROPCLEANBUFFERS;
SET STATISTICS IO ON;
SELECT	SalesOrderID, OrderDate, SubTotal, TaxAmt
FROM	Sales.SalesOrderHeader WITH (NOLOCK)
SET STATISTICS IO OFF;
GO
-- Table 'SalesOrderHeader'. Scan count 1, logical reads 688, physical reads 0, read-ahead reads 702, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.

-- without NOLOCK allocation-order is not used to protect isolation 
DBCC DROPCLEANBUFFERS;
SET STATISTICS IO ON;
SELECT	SalesOrderID, OrderDate, SubTotal, TaxAmt
FROM	Sales.SalesOrderHeader;
SET STATISTICS IO OFF;
GO
-- Table 'SalesOrderHeader'. Scan count 1, logical reads 689, physical reads 3, read-ahead reads 685, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.

------------------------------------------------------------------------
-- Unordered Covering Non-Clustered Index Scan (full) allocation-order
------------------------------------------------------------------------
-- Note: same remarks as previous example
DBCC DROPCLEANBUFFERS;
SET STATISTICS IO ON;
SELECT	ProductID, SalesOrderID
FROM	Sales.SalesOrderDetail WITH (NOLOCK)
SET STATISTICS IO OFF;
GO
-- Table 'SalesOrderDetail'. Scan count 1, logical reads 275, physical reads 0, read-ahead reads 289, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
DBCC DROPCLEANBUFFERS;
SET STATISTICS IO ON;
SELECT	ProductID, SalesOrderID
FROM	Sales.SalesOrderDetail;
SET STATISTICS IO OFF;
GO
-- Table 'SalesOrderDetail'. Scan count 1, logical reads 276, physical reads 1, read-ahead reads 288, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.

------------------------------------------------------------------------
-- Unordered Clustered Index Scan (full) index-order
------------------------------------------------------------------------
-- Note: we are using a hint to force parallelism and usually get
-- unordered rows
SELECT	SalesOrderID, OrderQty
FROM	Sales.SalesOrderDetail
WHERE	OrderQty > 5
OPTION	(USE HINT('ENABLE_PARALLEL_PLAN_PREFERENCE'));
GO

------------------------------------------------------------------------
-- Unordered Covering Non-Clustered Index Scan (full) index-order
------------------------------------------------------------------------
-- The query uses index IX_SalesOrderDetail_ProductID because it's 
-- smaller to scan and still has SalesOrderID in leaf pages since
-- that is the clustering key
-- Note: we are using a hint to force parallelism and usually get
-- unordered rows
SELECT	SalesOrderID, COUNT(*)
FROM	Sales.SalesOrderDetail
GROUP BY SalesOrderID
OPTION	(USE HINT('ENABLE_PARALLEL_PLAN_PREFERENCE'))
GO

------------------------------------------------------------------------
-- Ordered Clustered Index Scan (full) index-order
------------------------------------------------------------------------
-- Note: even with the Hint, the result is ordered as specified
SELECT	SalesOrderID, OrderQty
FROM	Sales.SalesOrderDetail
WHERE	OrderQty > 5
ORDER BY SalesOrderID
OPTION	(USE HINT('ENABLE_PARALLEL_PLAN_PREFERENCE'));
GO

------------------------------------------------------------------------
-- Ordered Covering Non-Clustered Index Scan (full) index-order
------------------------------------------------------------------------
-- Note: the result is ordered as specified but we have to remove the
-- hint otherwise the optimizer may choose to still do an unordered
-- scan and sort the intermediate results after
SELECT	SalesOrderID, COUNT(*)
FROM	Sales.SalesOrderDetail
GROUP BY SalesOrderID
ORDER BY SalesOrderID
OPTION	(USE HINT('ENABLE_PARALLEL_PLAN_PREFERENCE'))
GO

------------------------------------------------------------------------
-- Non-Clustered Index Seek + Range Scan + Lookups
-- RID Lookups on a Heap
------------------------------------------------------------------------
CREATE INDEX IX_DatabaseLog_Event ON dbo.DatabaseLog([Event]);
GO
SELECT	PostTime, [schema], [object]
FROM	dbo.DatabaseLog
WHERE	[Event] = 'ALTER_TABLE'
GO
DROP INDEX IX_DatabaseLog_Event ON dbo.DatabaseLog;
GO

------------------------------------------------------------------------
-- Non-Clustered Index Seek + Range Scan + Lookups
-- Key Lookups on a Clustered Index
-- Note: forcing LOOP JOIN to avoid cascading HASH JOINS in some cases
------------------------------------------------------------------------
SELECT	SalesOrderID, [Status], OrderDate
FROM	Sales.SalesOrderHeader
WHERE	SalesOrderNumber BETWEEN N'SO43600' AND N'SO43800'
OPTION(LOOP JOIN);
GO 

------------------------------------------------------------------------
-- Unordered Non-Clustered Index Scan + Lookups
-- Key Lookups on a Clustered Index
-- Note: filter needs to be selective, index column not leading and
-- not covering
------------------------------------------------------------------------
CREATE INDEX IX_SalesOrderHeader_OrderMisc
ON Sales.SalesOrderHeader(OrderDate, PurchaseOrderNumber);
GO
--CREATE INDEX IX_SalesOrderHeader_OrderMisc
--ON Sales.SalesOrderHeader(PurchaseOrderNumber);
--GO
SELECT	SalesOrderID, [Status], OrderDate, PurchaseOrderNumber
FROM	Sales.SalesOrderHeader
WHERE	PurchaseOrderNumber = N'PO9599137631';
GO
DROP INDEX IX_SalesOrderHeader_OrderMisc ON Sales.SalesOrderHeader;
GO

------------------------------------------------------------------------
-- Covering Non-Clustered Index Seek + Range Scan
------------------------------------------------------------------------
SELECT	SalesOrderID, SalesPersonID
FROM	Sales.SalesOrderHeader
WHERE	SalesPersonID = 279;
GO
