------------------------------------------------------------------------
-- Copyright:   2018 Gianluca Hotz
-- License:     MIT License
--              Permission is hereby granted, free of charge, to any
--              person obtaining a copy of this software and associated
--              documentation files (the "Software"), to deal in the
--              Software without restriction, including without
--              limitation the rights to use, copy, modify, merge,
--              publish, distribute, sublicense, and/or sell copies of
--              the Software, and to permit persons to whom the
--              Software is furnished to do so, subject to the
--              following conditions:
--              
--              The above copyright notice and this permission notice
--              shall be included in all copies or substantial portions
--              of the Software.
--              
--              THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
--              ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
--              LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
--              FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
--              EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
--              FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
--              AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--              OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
--              OTHER DEALINGS IN THE SOFTWARE.
-- Synopsis:    Lo scopo di questo script e' di generare i dati di prova che saranno
--              utilizzati in alcuni dei successivi script.
-- 
--              Modificare i percorsi sopra elencati coerentemente con quelli
-- 				della propria installazione.
--
-- 				Lo script genera delle tabelle nel database di sistema tempdb ed
-- 				esporta in dati in formato carattere utilizzando la utility bcp.exe
-- 				chiamata direttamente tramite le funzionalita' di scripting della
-- 				modalita' SQLCMD che deve essere quindi attivata
--
-- 				In testa allo script sono definite delle variabili per pilotare
-- 				il numero di righe che si vogliono generare per le varie tabelle,
-- 				la data di partenza per le tabelle che prevedeono un attributo di
-- 				tipo data ed il numero di anni consecutivi per i quali si vuole
-- 				generare i dati.
--
-- 				Nota bene: i dati vengono generati con una sola transazione per ogni
-- 				tabella, il log del tempdb deve essere quindi dimensionato
-- 				opportunamente (oppure si puo' spezzare la transazione in piu'
-- 				transazioni all'interno di un ciclo).
-- Credits:     
------------------------------------------------------------------------
-- Search/replace paths in this script:
--
-- Default paths:       C:\Temp\demos\partitioning
-- Default instances:   localhost
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Cambiamo contesto.
------------------------------------------------------------------------
USE tempdb
GO

------------------------------------------------------------------------
-- Dichiarazione variabili con valori di default per la generazione
-- dei dati.
------------------------------------------------------------------------
DECLARE	@NumOrders	AS int;
DECLARE	@NumCustomers	AS int;
DECLARE	@NumEmployees	AS int;
DECLARE	@NumShippers	AS int;
DECLARE	@NumYears	AS int;
DECLARE	@StartDate	AS datetime;

SET	@NumOrders		=   1000000;
SET	@NumCustomers	=     20000;
SET	@NumEmployees	=       500;
SET	@NumShippers	=         5;
SET	@NumYears	=         4;
SET	@StartDate	= '20030101';

------------------------------------------------------------------------
-- Creiamo una tabella di supporto con numeri interi da 1 a 1 milione.
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
-- Creiamo la tabella dei clienti con dati di test.
------------------------------------------------------------------------
IF OBJECT_ID('dbo.Customers') IS NOT NULL
	DROP TABLE dbo.Customers;

CREATE TABLE dbo.Customers
(
	CustomerID	char(11)	NOT NULL
,	CustomerName	nvarchar(50)	NOT NULL
);

INSERT	dbo.Customers (CustomerID, CustomerName)
SELECT
	'C' + RIGHT('000000000' + CAST(n AS varchar(10)), 10) AS CustomerID
,	N'Cust_' + CAST(n AS varchar(10)) AS CustomerName
FROM	dbo.Numbers
WHERE	n <= @NumCustomers;

ALTER TABLE	dbo.Customers
ADD
CONSTRAINT	PK_Customers
PRIMARY KEY	(CustomerID);

CHECKPOINT

------------------------------------------------------------------------
-- Creiamo la tabella degli impiegati con dati di test.
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

ALTER TABLE dbo.Employees ADD
  CONSTRAINT PK_Employees PRIMARY KEY(EmployeeID);

CHECKPOINT

------------------------------------------------------------------------
-- Creiamo la tabella degli spedizioneri con dati di test.
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
-- Creiamo la tabella degli ordini con dati di test.
------------------------------------------------------------------------
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
);

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
GO

------------------------------------------------------------------------
-- Creiamo la chiave primaria (clustered) per gli ordini.
------------------------------------------------------------------------
ALTER TABLE	dbo.Orders
ADD
CONSTRAINT	PK_Orders
PRIMARY KEY	CLUSTERED (OrderDate, OrderID)
GO

------------------------------------------------------------------------
-- Generiamo i file di formato.
------------------------------------------------------------------------
!! bcp tempdb.dbo.Customers format C:\Temp\demos\partitioning\00.dati-customers.txt -f C:\Temp\demos\partitioning\00.dati-customers.fmt -c -T -Slocalhost
!! bcp tempdb.dbo.Employees format C:\Temp\demos\partitioning\00.dati-employees.txt -f C:\Temp\demos\partitioning\00.dati-employees.fmt -c -T -Slocalhost
!! bcp tempdb.dbo.Shippers format C:\Temp\demos\partitioning\00.dati-shippers.txt -f C:\Temp\demos\partitioning\00.dati-shippers.fmt -c -T -Slocalhost
!! bcp tempdb.dbo.Orders format C:\Temp\demos\partitioning\00.dati-Orders.txt -f C:\Temp\demos\partitioning\00.dati-Orders.fmt -c -T -Slocalhost
GO

------------------------------------------------------------------------
-- Esportiamo tutti i dati tranne gli ordini.
------------------------------------------------------------------------
!! bcp tempdb.dbo.Customers out C:\Temp\demos\partitioning\00.dati-customers.txt -c -T -Slocalhost
!! bcp tempdb.dbo.Employees out C:\Temp\demos\partitioning\00.dati-employees.txt -c -T -Slocalhost
!! bcp tempdb.dbo.Shippers out C:\Temp\demos\partitioning\00.dati-shippers.txt -c -T -Slocalhost
!! bcp tempdb.dbo.Orders out C:\Temp\demos\partitioning\00.dati-Orders.txt -c -T -Slocalhost
GO

------------------------------------------------------------------------
-- Esportiamo anche gli ordini suddivisi per anno.
------------------------------------------------------------------------
!! bcp "SELECT * FROM tempdb.dbo.Orders WHERE YEAR(OrderDate) = 2002 ORDER BY OrderDate, OrderID" queryout C:\Temp\demos\partitioning\00.dati-Orders-2002.txt -c -T -Slocalhost
!! bcp "SELECT * FROM tempdb.dbo.Orders WHERE YEAR(OrderDate) = 2003 ORDER BY OrderDate, OrderID" queryout C:\Temp\demos\partitioning\00.dati-Orders-2003.txt -c -T -Slocalhost
!! bcp "SELECT * FROM tempdb.dbo.Orders WHERE YEAR(OrderDate) = 2004 ORDER BY OrderDate, OrderID" queryout C:\Temp\demos\partitioning\00.dati-Orders-2004.txt -c -T -Slocalhost
!! bcp "SELECT * FROM tempdb.dbo.Orders WHERE YEAR(OrderDate) = 2005 ORDER BY OrderDate, OrderID" queryout C:\Temp\demos\partitioning\00.dati-Orders-2005.txt -c -T -Slocalhost
!! bcp "SELECT * FROM tempdb.dbo.Orders WHERE YEAR(OrderDate) = 2006 ORDER BY OrderDate, OrderID" queryout C:\Temp\demos\partitioning\00.dati-Orders-2006.txt -c -T -Slocalhost
GO
