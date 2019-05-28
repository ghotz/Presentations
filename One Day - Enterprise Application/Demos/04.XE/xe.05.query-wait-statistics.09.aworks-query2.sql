------------------------------------------------------------------------
-- Copyright:   2016 Gianluca Hotz
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
USE AdventureWorks2012;
GO

SELECT	COUNT(*)
FROM
	(
	SELECT C.CustomerID
		, M1.maxSalesOrderId
		, M.maxOrderDate
	FROM Sales.Customer AS C
	INNER JOIN (
		SELECT CustomerID
			, maxOrderDate = MAX(orderDate)
		FROM Sales.SalesOrderHeader AS SH
		GROUP BY CustomerID
	) AS M
		ON C.CustomerID = M.CustomerID
	INNER JOIN (
		SELECT CustomerId
			, orderDate
			, maxSalesOrderId = MAX(salesOrderId)
		FROM Sales.SalesOrderHeader AS SH
		GROUP BY CustomerId
			, orderDate
	) AS M1
		ON  C.CustomerID = M1.CustomerID
		AND M.maxOrderDate = M1.OrderDate
	) AS T
GO 50

DBCC DROPCLEANBUFFERS;
GO

SELECT	COUNT(*)
FROM
	(
	SELECT C.CustomerID
		, M1.maxSalesOrderId
		, M.maxOrderDate
	FROM Sales.Customer AS C
	INNER JOIN (
		SELECT CustomerID
			, maxOrderDate = MAX(orderDate)
		FROM Sales.SalesOrderHeader AS SH
		GROUP BY CustomerID
	) AS M
		ON C.CustomerID = M.CustomerID
	INNER JOIN (
		SELECT CustomerId
			, orderDate
			, maxSalesOrderId = MAX(salesOrderId)
		FROM Sales.SalesOrderHeader AS SH
		GROUP BY CustomerId
			, orderDate
	) AS M1
		ON  C.CustomerID = M1.CustomerID
		AND M.maxOrderDate = M1.OrderDate
	) AS T
GO 50