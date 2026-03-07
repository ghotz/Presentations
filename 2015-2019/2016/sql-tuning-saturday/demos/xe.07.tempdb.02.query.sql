USE tempdb;
GO
IF OBJECT_ID('tempdb..#temp') IS NOT NULL
	DROP TABLE #temp;
SELECT	*
INTO	#temp
FROM	AdventureWorks2012.Sales.SalesOrderDetail
UNION ALL
SELECT	*
FROM	AdventureWorks2012.Sales.SalesOrderDetail
UNION ALL
SELECT	*
FROM	AdventureWorks2012.Sales.SalesOrderDetail
GO