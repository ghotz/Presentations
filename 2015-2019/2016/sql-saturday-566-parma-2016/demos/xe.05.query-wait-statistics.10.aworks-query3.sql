USE AdventureWorks2012;
GO

SELECT	COUNT(*)
FROM
	(
	SELECT C.CustomerID
		, A.maxSalesOrderId
		, A.maxOrderDate
		, A.TotalDue
		, A.ShipDate
		, A.Status
	FROM Sales.Customer AS C
	CROSS APPLY ( 
		SELECT * 
		FROM (
			SELECT CustomerId
				,RN = ROW_NUMBER() OVER(
					PARTITION BY CustomerId 
					ORDER BY orderdate DESC, SalesOrderID DESC
				 )
				,SalesOrderID AS maxSalesOrderId
				,orderdate AS maxOrderDate
				,TotalDue
				,ShipDate
				,Status
			FROM Sales.SalesOrderHeader AS O
		) AS B
		WHERE RN = 1
			AND B.CustomerID = C.CustomerID
	) AS A
	) AS T
GO 50

DBCC DROPCLEANBUFFERS;
GO

SELECT	COUNT(*)
FROM
	(
	SELECT C.CustomerID
		, A.maxSalesOrderId
		, A.maxOrderDate
		, A.TotalDue
		, A.ShipDate
		, A.Status
	FROM Sales.Customer AS C
	CROSS APPLY ( 
		SELECT * 
		FROM (
			SELECT CustomerId
				,RN = ROW_NUMBER() OVER(
					PARTITION BY CustomerId 
					ORDER BY orderdate DESC, SalesOrderID DESC
				 )
				,SalesOrderID AS maxSalesOrderId
				,orderdate AS maxOrderDate
				,TotalDue
				,ShipDate
				,Status
			FROM Sales.SalesOrderHeader AS O
		) AS B
		WHERE RN = 1
			AND B.CustomerID = C.CustomerID
	) AS A
	) AS T
GO 50