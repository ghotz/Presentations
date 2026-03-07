------------------------------------------------------------------------
-- Script:			01.simple queries.sql
-- Last update:		2012-01-20
-- Author:			Gianluca Hotz  (SolidQ)
-- Credits:			
-- Copyright:		Attribution-NonCommercial-ShareAlike 3.0
-- Versions:		SQL2012
--
-- Description:		Demo SSMS environment
------------------------------------------------------------------------

-- Simple query
SELECT * FROM TSQL2012.HR.Employees;

-- Display execution plan 
SELECT	COUNT(*) AS NumOrders
FROM	TSQL2012.Sales.Orders;

SELECT	COUNT(*)  AS NumOrders
FROM	TSQL2012.Sales.Orders
WHERE	orderdate BETWEEN '20080101' AND '20080131';

-- Snippets CTRL+K CTRL+X

-- Surround with CTRL+K CTRL+S
