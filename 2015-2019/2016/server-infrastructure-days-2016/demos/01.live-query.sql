USE AdventureworksDW2016CTP3;
GO

--DBCC DROPCLEANBUFFERS;
--GO

SELECT	COUNT(*)
FROM	[dbo].[FactResellerSalesXL_PageCompressed] AS T1
JOIN	[dbo].[FactResellerSalesXL_PageCompressed] AS T2
  ON	T1.SalesOrderNumber = T2.SalesOrderNumber
 AND	T1.SalesOrderLineNumber = T2.SalesOrderLineNumber
GO
