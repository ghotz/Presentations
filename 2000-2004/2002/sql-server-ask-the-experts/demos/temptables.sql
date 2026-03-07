/*
** Demo tabelle temporanee
*/

USE Northwind
GO

/*
** Spesso sono utilizzate per suddividere
** una query piu' complessa come in questo
** esempio
*/
IF OBJECT_ID('dbo.VenditePerStati') IS NOT NULL
DROP PROCEDURE dbo.VenditePerStati
GO

CREATE PROCEDURE dbo.VenditePerStati
	@Beginning_Date	datetime,
	@Ending_Date	datetime
AS
SET NOCOUNT ON

SELECT	OD.OrderID,
	SUM(CAST(
	(OD.UnitPrice*OD.Quantity*(1-OD.Discount)/100)*100
	AS money)) AS Subtotal
INTO	#temp
FROM	dbo.[Order Details] AS OD
WHERE	OrderID IN
	(SELECT	OrderID
	 FROM	dbo.Orders AS O
	 WHERE	O.ShippedDate BETWEEN @Beginning_Date AND @Ending_Date
	)
GROUP BY
	OD.OrderID


SELECT	E.Country, E.LastName, E.FirstName,
	O.ShippedDate, O.OrderID, OS.Subtotal AS SaleAmount
FROM	Employees AS E
JOIN	Orders AS O
  ON	E.EmployeeID = O.EmployeeID
JOIN	#temp AS OS
  ON	O.OrderID = OS.OrderID
WHERE	O.ShippedDate BETWEEN @Beginning_Date AND @Ending_Date

GO

EXEC	dbo.VenditePerStati	'1997-01-01', '1997-06-01'
GO

/*
** Utilizzo di tabelle derivate
*/

IF OBJECT_ID('dbo.VenditePerStati') IS NOT NULL
DROP PROCEDURE dbo.VenditePerStati
GO

CREATE PROCEDURE dbo.VenditePerStati
	@Beginning_Date	datetime,
	@Ending_Date	datetime
AS
SET NOCOUNT ON

SELECT	E.Country, E.LastName, E.FirstName,
	O.ShippedDate, O.OrderID, OS.Subtotal AS SaleAmount
FROM	Employees AS E
JOIN	Orders AS O
  ON	E.EmployeeID = O.EmployeeID
JOIN	(SELECT	OD.OrderID,
		SUM(CAST(
		(OD.UnitPrice*OD.Quantity*(1-OD.Discount)/100)*100
		AS money)) AS Subtotal
	FROM	dbo.[Order Details] AS OD
	WHERE	OrderID IN
		(SELECT	OrderID
		 FROM	dbo.Orders AS O
		 WHERE	O.ShippedDate BETWEEN @Beginning_Date AND @Ending_Date
		)
	GROUP BY
		OD.OrderID
	) AS OS
  ON	O.OrderID = OS.OrderID
WHERE	O.ShippedDate BETWEEN @Beginning_Date AND @Ending_Date

GO

EXEC	dbo.VenditePerStati	'1997-01-01', '1997-06-01'
GO

/*
** Utilizzo di variabili di tipo tabella
*/
IF OBJECT_ID('dbo.VenditePerStati') IS NOT NULL
DROP PROCEDURE dbo.VenditePerStati
GO

CREATE PROCEDURE dbo.VenditePerStati
	@Beginning_Date	datetime,
	@Ending_Date	datetime
AS
SET NOCOUNT ON

DECLARE	@temp	table(
	OrderID		int	NOT NULL PRIMARY KEY,
	Subtotal	money	NOT NULL
)

INSERT	@temp
SELECT	OD.OrderID,
	SUM(CAST(
	(OD.UnitPrice*OD.Quantity*(1-OD.Discount)/100)*100
	AS money)) AS Subtotal
FROM	dbo.[Order Details] AS OD
WHERE	OrderID IN
	(SELECT	OrderID
	 FROM	dbo.Orders AS O
	 WHERE	O.ShippedDate BETWEEN @Beginning_Date AND @Ending_Date
	)
GROUP BY
	OD.OrderID


SELECT	E.Country, E.LastName, E.FirstName,
	O.ShippedDate, O.OrderID, OS.Subtotal AS SaleAmount
FROM	Employees AS E
JOIN	Orders AS O
  ON	E.EmployeeID = O.EmployeeID
JOIN	@temp AS OS
  ON	O.OrderID = OS.OrderID
WHERE	O.ShippedDate BETWEEN @Beginning_Date AND @Ending_Date

GO

EXEC	dbo.VenditePerStati	'1997-01-01', '1997-06-01'
GO

/*
** in alcuni casi sono utilizzate per gestire i dati
** ritornati da un'altra Stored Procedure
*/

IF OBJECT_ID('dbo.OrderSubTotals') IS NOT NULL
DROP PROCEDURE dbo.OrderSubTotals
GO

CREATE PROCEDURE dbo.OrderSubTotals
	@Beginning_Date	datetime,
	@Ending_Date	datetime
AS
SET NOCOUNT ON

SELECT	OD.OrderID,
	SUM(CAST(
	(OD.UnitPrice*OD.Quantity*(1-OD.Discount)/100)*100
	AS money)) AS Subtotal
FROM	dbo.[Order Details] AS OD
WHERE	OrderID IN
	(SELECT	OrderID
	 FROM	dbo.Orders AS O
	 WHERE	O.ShippedDate BETWEEN @Beginning_Date AND @Ending_Date
	)
GROUP BY
	OD.OrderID
GO

IF OBJECT_ID('dbo.VenditePerStati') IS NOT NULL
DROP PROCEDURE dbo.VenditePerStati
GO

CREATE PROCEDURE dbo.VenditePerStati
	@Beginning_Date	datetime,
	@Ending_Date	datetime
AS
SET NOCOUNT ON

CREATE TABLE #temp(
	OrderID		int	NOT NULL PRIMARY KEY,
	Subtotal	money	NOT NULL
)

INSERT	#temp
EXEC	dbo.OrderSubTotals @Beginning_Date, @Ending_Date


SELECT	E.Country, E.LastName, E.FirstName,
	O.ShippedDate, O.OrderID, OS.Subtotal AS SaleAmount
FROM	Employees AS E
JOIN	Orders AS O
  ON	E.EmployeeID = O.EmployeeID
JOIN	#temp AS OS
  ON	O.OrderID = OS.OrderID
WHERE	O.ShippedDate BETWEEN @Beginning_Date AND @Ending_Date

GO

EXEC	dbo.VenditePerStati	'1997-01-01', '1997-06-01'
GO

/*
** con SQL Server 2000 e' possibile usare le funzioni
*/
IF OBJECT_ID('dbo.fnOrderSubTotals') IS NOT NULL
DROP FUNCTION dbo.fnOrderSubTotals
GO

CREATE FUNCTION dbo.fnOrderSubTotals(
	@Beginning_Date	datetime,
	@Ending_Date	datetime
)
RETURNS @temp TABLE (
	OrderID		int	NOT NULL PRIMARY KEY,
	Subtotal	money	NOT NULL
)
AS
BEGIN
	INSERT	@temp
	SELECT	OD.OrderID,
		SUM(CAST(
		(OD.UnitPrice*OD.Quantity*(1-OD.Discount)/100)*100
		AS money)) AS Subtotal
	FROM	dbo.[Order Details] AS OD
	WHERE	OrderID IN
		(SELECT	OrderID
		 FROM	dbo.Orders AS O
		 WHERE	O.ShippedDate BETWEEN @Beginning_Date AND @Ending_Date
		)
	GROUP BY
		OD.OrderID
	RETURN
END
GO

IF OBJECT_ID('dbo.VenditePerStati') IS NOT NULL
DROP PROCEDURE dbo.VenditePerStati
GO

CREATE PROCEDURE dbo.VenditePerStati
	@Beginning_Date	datetime,
	@Ending_Date	datetime
AS
SET NOCOUNT ON

SELECT	E.Country, E.LastName, E.FirstName,
	O.ShippedDate, O.OrderID, OS.Subtotal AS SaleAmount
FROM	Employees AS E
JOIN	Orders AS O
  ON	E.EmployeeID = O.EmployeeID
JOIN	dbo.fnOrderSubTotals(@Beginning_Date, @Ending_Date) AS OS
  ON	O.OrderID = OS.OrderID
WHERE	O.ShippedDate BETWEEN @Beginning_Date AND @Ending_Date

GO

EXEC	dbo.VenditePerStati	'1997-01-01', '1997-06-01'
GO
