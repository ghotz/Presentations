------------------------------------------------------------------------
-- GREATEST/LEAST
------------------------------------------------------------------------
USE tempdb;
GO

-- simple demo
SELECT GREATEST(6.5, 3.5, 7) AS greatest_of_numbers;
SELECT LEAST(6.5, 3.5, 7) as smallest_of_numbers;
GO

-- NULLs behavior
SELECT GREATEST(6.5, NULL, 3.5, 7) as greatest_of_numbers;
SELECT LEAST(6.5, NULL, 3.5, 7) as smallest_of_numbers;
GO

-- datatype precedence
SELECT GREATEST('6.62', 3.1415, N'7') AS GreatestVal;
SELECT LEAST('6.62', 3.1415, N'7') AS LeastVal;
GO

-- Strings
SELECT GREATEST('Glacier', N'Joshua Tree', 'Mount Rainier') AS GreatestString;
SELECT LEAST('Glacier', N'Joshua Tree', 'Mount Rainier') AS LeastString;
GO

-- example with dates
USE AdventureWorksLT2022;
GO
SELECT P.Name,
    P.SellStartDate,
    P.DiscontinuedDate,
    PM.ModifiedDate AS ModelModifiedDate,
    GREATEST(P.SellStartDate, P.DiscontinuedDate, PM.ModifiedDate) AS LatestDate,
	LEAST(P.SellStartDate, P.DiscontinuedDate, PM.ModifiedDate) AS EarliestDate
FROM SalesLT.Product AS P
INNER JOIN SalesLT.ProductModel AS PM
    ON P.ProductModelID = PM.ProductModelID
WHERE GREATEST(P.SellStartDate, P.DiscontinuedDate, PM.ModifiedDate) >= '2007-01-01'
    AND P.SellStartDate >= '2007-01-01'
    AND P.Name LIKE 'Touring %'
ORDER BY P.Name;
GO
