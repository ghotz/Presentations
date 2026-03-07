/*
** Transact-SQL XML Demo
** Nota: aumentare il numero di char in QA
*/

USE Northwind
GO

-- FOR XML RAW: schema generico (riga)
SELECT	CustomerID, CompanyName
FROM	Customers
WHERE	Country = 'Italy'
FOR XML RAW
GO

-- FOR XML AUTO: deriva direttamente lo schema
SELECT	CustomerID, CompanyName
FROM	Customers
WHERE	Country = 'Italy'
FOR XML AUTO
GO

SELECT	Customers.CustomerID
,	Customers.CompanyName
,	Orders.OrderID
,	Orders.OrderDate
FROM	Customers
JOIN	Orders
  ON	Customers.CustomerID = Orders.CustomerID
WHERE	Customers.Country = 'Italy' AND
	YEAR(Orders.OrderDate) = 1998
ORDER BY
	Customers.CompanyName
,	Orders.OrderDate
FOR XML AUTO
