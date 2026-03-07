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
GO 100

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
GO 100