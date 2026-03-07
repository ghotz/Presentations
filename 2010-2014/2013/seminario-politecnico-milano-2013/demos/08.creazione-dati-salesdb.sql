------------------------------------------------------------------------
--
-- Script:		03.creazione-dati-salesdb.sql
-- Author:		Gianluca Hotz (Solid Quality Learning)
-- Credits:		Itzik Ben Gan (Solid Quality Learning)
-- Copyright:	Attribution-NonCommercial-ShareAlike 2.5
-- Version:		SQL Server 2000/2005/2008
--
-- Default paths:
--
-- Lo scopo di questo script e' di generare i dati di prova che saranno
-- utilizzati in alcuni dei successivi script.
-- 
-- Modificare i percorsi sopra elencati coerentemente con quelli
-- della propria installazione.
--
-- In testa allo script sono definite delle variabili per pilotare
-- il numero di righe che si vogliono generare per le varie tabelle,
-- la data di partenza per le tabelle che prevedeono un attributo di
-- tipo data ed il numero di anni consecutivi per i quali si vuole
-- generare i dati.
--
-- Nota bene: i dati vengono generati con una sola transazione per ogni
-- tabella, il log del tempdb deve essere quindi dimensionato
-- opportunamente (oppure si puo' spezzare la transazione in piu'
-- transazioni all'interno di un ciclo).
--
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Dichiarazione variabili con valori di default per la generazione
-- dei dati.
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Cambiamo il contesto.
------------------------------------------------------------------------
USE SalesDB
GO

DECLARE	@NumOrders	AS int;
DECLARE	@NumCustomers	AS int;
DECLARE	@NumEmployees	AS int;
DECLARE	@NumShippers	AS int;
DECLARE	@NumYears	AS int;
DECLARE	@StartDate	AS datetime;

SET	@NumOrders	=   1000000;
SET	@NumCustomers	=     20000;
SET	@NumEmployees	=       500;
SET	@NumShippers	=         5;
SET	@NumYears	=         2;
SET	@StartDate	= '20050101';


------------------------------------------------------------------------
-- Creiamo una tabella di supporto con numeri interi da 1 a 1 milione.
-- Nota: viene creata sul filegroup di default DEFDATA
------------------------------------------------------------------------
IF OBJECT_ID('dbo.Numbers') IS NOT NULL
	DROP TABLE dbo.Numbers;

CREATE TABLE dbo.Numbers(n int NOT NULL PRIMARY KEY);

DECLARE	@MaxNumber	int
,	@RowCount	int;

SET	@MaxNumber = 1000000;
SET	@RowCount = 1;

INSERT dbo.Numbers VALUES(1);

WHILE	@RowCount * 2 <= @MaxNumber
BEGIN
	INSERT	dbo.Numbers 
	SELECT	n + @RowCount
	FROM	dbo.Numbers;

	SET	@RowCount = @RowCount * 2;
END

INSERT	dbo.Numbers 
SELECT	n + @RowCount
FROM	dbo.Numbers
WHERE	n + @RowCount <= @MaxNumber;

CHECKPOINT

------------------------------------------------------------------------
-- Creazione tabella dei clienti con dati di test.
------------------------------------------------------------------------
IF OBJECT_ID('dbo.Customers') IS NOT NULL
	DROP TABLE dbo.Customers;

CREATE TABLE dbo.Customers
(
	CustomerID	char(11)	NOT NULL
,	CustomerName	nvarchar(50)	NOT NULL
) ON CUSTOMERS;

INSERT	dbo.Customers (CustomerID, CustomerName)
SELECT
	'C' + RIGHT('000000000' + CAST(n AS varchar(10)), 10) AS CustomerID
,	N'Cust_' + CAST(n AS varchar(10)) AS CustomerName
FROM	dbo.Numbers
WHERE	n <= @NumCustomers;

ALTER TABLE	dbo.Customers
ADD
CONSTRAINT	PK_Customers
PRIMARY KEY	(CustomerID)
ON		CUSTOMERS;

CHECKPOINT

------------------------------------------------------------------------
-- Creazione tabella degli impiegati con dati di test.
-- Nota: viene creata sul filegroup di default DEFDATA
------------------------------------------------------------------------
IF OBJECT_ID('dbo.Employees') IS NOT NULL
	DROP TABLE dbo.Employees;

CREATE TABLE dbo.Employees
(
	EmployeeID	int		NOT NULL
,	FirstName	nvarchar(25)	NOT NULL
,	LastName	nvarchar(25)	NOT NULL
);

INSERT	dbo.Employees(EmployeeID, FirstName, LastName)
SELECT
	n AS EmployeeID
,	N'Fname_' + CAST(n AS nvarchar(10)) AS FirstName
,	N'Lname_' + CAST(n AS NVARCHAR(10)) AS LastName
FROM	dbo.Numbers
WHERE	n <= @NumEmployees;

ALTER TABLE	dbo.Employees
ADD
CONSTRAINT	PK_Employees
PRIMARY KEY	(EmployeeID);

CHECKPOINT

------------------------------------------------------------------------
-- Creiamo la tabella degli spedizioneri con dati di test.
-- Nota: viene creata sul filegroup di default DEFDATA
------------------------------------------------------------------------
IF OBJECT_ID('dbo.Shippers') IS NOT NULL
	DROP TABLE dbo.Shippers;

CREATE TABLE dbo.Shippers
(
	ShipperID	varchar(5)	NOT NULL
,	ShipperName	nvarchar(50)	NOT NULL
);

INSERT	dbo.Shippers(ShipperID, ShipperName)
SELECT
	ShipperID
,	N'Shipper_' + shipperid AS ShipperName
FROM	(
	SELECT	CHAR(ASCII('A') - 2 + 2 * n) AS ShipperID
        FROM	dbo.Numbers
        WHERE	n <= @NumShippers
	) AS D;

ALTER TABLE	dbo.Shippers
ADD
CONSTRAINT	PK_Shippers
PRIMARY KEY	(ShipperID);

CHECKPOINT

------------------------------------------------------------------------
-- Creazione funzione di partizionamento.
------------------------------------------------------------------------
CREATE PARTITION FUNCTION TwoYearDateRangePFN(datetime)
AS RANGE LEFT FOR VALUES (
	'2005-01-31 23:59:59.997'
,	'2005-02-28 23:59:59.997'
,	'2005-03-31 23:59:59.997'
,	'2005-04-30 23:59:59.997'
,	'2005-05-31 23:59:59.997'
,	'2005-06-30 23:59:59.997'
,	'2005-07-31 23:59:59.997'
,	'2005-08-31 23:59:59.997'
,	'2005-09-30 23:59:59.997'
,	'2005-10-31 23:59:59.997'
,	'2005-11-30 23:59:59.997'
,	'2005-12-31 23:59:59.997'
,	'2006-01-31 23:59:59.997'
,	'2006-02-28 23:59:59.997'
,	'2006-03-31 23:59:59.997'
,	'2006-04-30 23:59:59.997'
,	'2006-05-31 23:59:59.997'
,	'2006-06-30 23:59:59.997'
,	'2006-07-31 23:59:59.997'
,	'2006-08-31 23:59:59.997'
,	'2006-09-30 23:59:59.997'
,	'2006-10-31 23:59:59.997'
,	'2006-11-30 23:59:59.997'
,	'2006-12-31 23:59:59.997'
);

------------------------------------------------------------------------
-- Creazione schema di partizionamento.
------------------------------------------------------------------------
CREATE PARTITION SCHEME TwoYearDateRangePScheme
AS PARTITION TwoYearDateRangePFN TO (
	OrdersFG01
,	OrdersFG02
,	OrdersFG03
,	OrdersFG04
,	OrdersFG05
,	OrdersFG06
,	OrdersFG07
,	OrdersFG08
,	OrdersFG09
,	OrdersFG10
,	OrdersFG11
,	OrdersFG12
,	OrdersFG13
,	OrdersFG14
,	OrdersFG15
,	OrdersFG16
,	OrdersFG17
,	OrdersFG18
,	OrdersFG19
,	OrdersFG20
,	OrdersFG21
,	OrdersFG22
,	OrdersFG23
,	OrdersFG24
,	"DEFDATA"
)
GO

------------------------------------------------------------------------
-- Creiamo la tabella degli ordini con dati di test.
------------------------------------------------------------------------
DECLARE	@NumOrders	AS int;
DECLARE	@NumCustomers	AS int;
DECLARE	@NumEmployees	AS int;
DECLARE	@NumShippers	AS int;
DECLARE	@NumYears	AS int;
DECLARE	@StartDate	AS datetime;

SET	@NumOrders	=   1000000;
SET	@NumCustomers	=     20000;
SET	@NumEmployees	=       500;
SET	@NumShippers	=         5;
SET	@NumYears	=         2;
SET	@StartDate	= '20050101';
IF OBJECT_ID('dbo.Orders') IS NOT NULL
  DROP TABLE dbo.Orders;

CREATE TABLE dbo.Orders
(
	OrderID		int		NOT NULL
,	CustomerID	char(11)	NOT NULL
,	EmployeeID	int		NOT NULL
,	ShipperID	varchar(5)	NOT NULL
,	OrderDate	datetime	NOT NULL
,	Filler		char(155)	NOT NULL
			CONSTRAINT	df_Orders
			DEFAULT		('a')
) ON TwoYearDateRangePScheme(OrderDate);

INSERT	dbo.Orders(OrderID, CustomerID, EmployeeID, ShipperID, OrderDate)
SELECT
	n AS OrderID
,	'C' + RIGHT('000000000'
            + CAST(
                CEILING(
                  0.9999999999 * RAND(CHECKSUM(NEWID()))
                   * @NumCustomers)
                AS VARCHAR(10)), 10) AS CustomerID
,	CEILING(0.9999999999 * RAND(CHECKSUM(NEWID()))
              * @NumEmployees) AS EmployeeID
,	CHAR(ASCII('A') - 2
           + 2 * CEILING(0.9999999999 * RAND(CHECKSUM(NEWID()))
                           * @NumShippers)) AS ShipperID
,	DATEADD(day, n / (@NumOrders / (@NumYears * 365.25)), @StartDate)
        -- late order
        - CASE WHEN n % 10 = 0
            THEN CEILING(0.9999999999 * RAND(CHECKSUM(NEWID())) * 30)
            ELSE 0 
          END AS OrderDate
FROM	dbo.Numbers
WHERE	n <= @NumOrders
ORDER BY	
	RAND(CHECKSUM(NEWID()));

------------------------------------------------------------------------
-- Creiamo la chiave primaria (clustered) per gli ordini.
------------------------------------------------------------------------
ALTER TABLE	dbo.Orders
ADD
CONSTRAINT	PK_Orders
PRIMARY KEY	CLUSTERED (OrderDate, OrderID)
ON		TwoYearDateRangePScheme(OrderDate)
GO
