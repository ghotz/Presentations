USE AdventureWorks2012;
GO

SELECT	COUNT(*)
FROM
	(
	SELECT sd.UnitPrice, dbo.ufnGetProductListPrice(sd.ProductID, sh.OrderDate) AS ListPrice
	FROM Sales.SalesOrderDetail AS sd
	INNER JOIN Sales.SalesOrderHeader AS sh
		ON sd.SalesOrderID = sh.SalesOrderID
	) AS T
GO 50

DBCC DROPCLEANBUFFERS;
GO

SELECT	COUNT(*)
FROM
	(
	SELECT sd.UnitPrice, dbo.ufnGetProductListPrice(sd.ProductID, sh.OrderDate) AS ListPrice
	FROM Sales.SalesOrderDetail AS sd
	INNER JOIN Sales.SalesOrderHeader AS sh
		ON sd.SalesOrderID = sh.SalesOrderID
	) AS T
GO 50
