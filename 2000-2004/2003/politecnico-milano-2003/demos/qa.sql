/*
** Demo Query Analyzer
** - sintassi colorata
** - finestre multiple
** - viste a griglia o solo testo
** - piano di esecuzione grafico
** - esecuzione di porzioni di script
** - apertura diretta tabelle
** - generazione scripts oggetti
** - utilizzo di templates
** - debug stored procedure
*/
USE Northwind
GO

SELECT	*
FROM	Northwind.dbo.Employees
WHERE	LastName = 'Davolio'
GO

/*
** Variabili locali
*/
DECLARE	@LastName 	char(20)
,	@FirstName	varchar(11)

SET	@LastName = 'Dodsworth'

SELECT	@FirstName = FirstName
FROM	Northwind..Employees
WHERE	LastName = @LastName

PRINT	@LastName + ' ' + @FirstName
GO

-- SELECT puo' essere usata per assegnare
-- piu' valori
DECLARE	@LastName 	char(20)
,	@FirstName	varchar(11)

SELECT	@FirstName = FirstName
,	@LastName = LastName
FROM	Northwind..Employees
WHERE	EmployeeID = 7

PRINT	@LastName + ' ' + @FirstName
GO


/*
** Operatori
**
** aritmetici + - * /%
**
** comparazione = > < >= <= <> !=
**
** logici AND OR NOT
**
** concatenazione stringhe +
*/

SELECT 'pippo' + ' ' + ' pluto' AS Stringa
GO

/*
** Funzioni
*/

-- aggregazione
SELECT	ProductID
,	SUM(Quantity) AS Totale
FROM	Northwind.dbo.[Order Details]
GROUP BY
	ProductID
ORDER BY
	ProductID
GO

-- scalari
SELECT	DB_NAME()

SELECT	GETDATE()

SELECT	RIGHT(LastName, 3)
FROM	Northwind.dbo.Employees
GO

SELECT	'ANSI:' AS Region
,	CONVERT(varchar(30), GETDATE(), 102) AS Style
UNION
SELECT	'European:', CONVERT(varchar(30), GETDATE(), 113)
UNION
SELECT	'Japanese:', CONVERT(varchar(30), GETDATE(), 111)
GO

/*
** controllo del flusso
*/
IF EXISTS(
	SELECT	OrderID
	FROM	Northwind.dbo.Orders
	WHERE	CustomerID = 'Frank'
	)
		PRINT '*** Il cliente non può essere cancellato ***'
ELSE
	BEGIN
		DELETE	Northwind.dbo.Customers
		WHERE	CustomerID = 'Frank'

		PRINT '*** Cliente cancellato ***'
	END
GO

/*
** CASE
*/

SELECT	ProductID
,	'Product Inventory Status' =
	CASE 
	WHEN (UnitsInStock < UnitsOnOrder AND Discontinued = 0)
	THEN 'Richieste superiori a scorte di magazzino, ordinare subito!'

	WHEN ((UnitsInStock-UnitsOnOrder) < ReorderLevel AND Discontinued = 0)
	THEN 'Livello di riordino raggiunto, ordinare il prodotto.'

	WHEN (Discontinued = 1) -- commento
	THEN '***Prodotto non più venduto***'

	ELSE 'Prodotto in stock'
   END
FROM Northwind.dbo.Products
GO

/*
** T-SQL Batches
*/

DECLARE	@LastName 	char(20)
,	@FirstName	varchar(11)

SET	@LastName = 'Dodsworth'

SELECT	@FirstName = FirstName
FROM	Northwind..Employees
WHERE	LastName = @LastName

PRINT	@LastName + ' ' + @FirstName
GO
