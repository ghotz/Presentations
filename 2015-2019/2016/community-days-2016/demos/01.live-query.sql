------------------------------------------------------------------------
--	Description:	Live Query Demo
------------------------------------------------------------------------
USE AdventureworksDW2016CTP3;
GO

--DBCC DROPCLEANBUFFERS;
--GO

--
--	1. Prepare Activity Monitor open with 1 second refresh iterval
--	2. Activate "Include Live Query Statistics"
--	3. Run Query and look at live plan
--	4. Switch to Activity Montor, right-select on query and select "Show Live Execution Plan"
--
SELECT	COUNT(*)
FROM	[dbo].[FactResellerSalesXL_PageCompressed] AS T1
JOIN	[dbo].[FactResellerSalesXL_PageCompressed] AS T2
  ON	T1.SalesOrderNumber = T2.SalesOrderNumber
 AND	T1.SalesOrderLineNumber = T2.SalesOrderLineNumber
GO

