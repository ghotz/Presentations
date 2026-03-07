/*
** Demo partitioned views
*/

IF OBJECT_ID('dbo.Orders10000_10500') IS NOT NULL
DROP TABLE dbo.Orders10000_10500
GO

CREATE TABLE dbo.Orders10000_10500 (
	OrderID int NOT NULL ,
	CustomerID nchar (5) NULL ,
	EmployeeID int NULL ,
	OrderDate datetime NULL ,
	RequiredDate datetime NULL ,
	ShippedDate datetime NULL ,
	ShipVia int NULL ,
	Freight money NULL CONSTRAINT DF_Orders10000_10500_Freight DEFAULT (0),
	ShipName nvarchar (40) NULL ,
	ShipAddress nvarchar (60) NULL ,
	ShipCity nvarchar (15) NULL ,
	ShipRegion nvarchar (15) NULL ,
	ShipPostalCode nvarchar (10) NULL ,
	ShipCountry nvarchar (15) NULL ,
	CONSTRAINT PK_Orders10000_10500 PRIMARY KEY  CLUSTERED 
	(
		OrderID
	),
	CONSTRAINT CK_Orders10000_10500_partition
	CHECK 	(OrderID BETWEEN 10000 AND 10500),
	CONSTRAINT FK_Orders10000_10500_Customers FOREIGN KEY 
	(
		CustomerID
	) REFERENCES Customers (
		CustomerID
	),
	CONSTRAINT FK_Orders10000_10500_Employees FOREIGN KEY 
	(
		EmployeeID
	) REFERENCES Employees (
		EmployeeID
	),
	CONSTRAINT FK_Orders10000_10500_Shippers FOREIGN KEY 
	(
		ShipVia
	) REFERENCES Shippers (
		ShipperID
	)
)
GO

INSERT	dbo.Orders10000_10500
SELECT	*
FROM	dbo.Orders
WHERE	OrderID BETWEEN 10000 AND 10500
GO

IF OBJECT_ID('dbo.Orders10500_11000') IS NOT NULL
DROP TABLE dbo.Orders10500_11000
GO

CREATE TABLE dbo.Orders10500_11000 (
	OrderID int NOT NULL ,
	CustomerID nchar (5) NULL ,
	EmployeeID int NULL ,
	OrderDate datetime NULL ,
	RequiredDate datetime NULL ,
	ShippedDate datetime NULL ,
	ShipVia int NULL ,
	Freight money NULL CONSTRAINT DF_Orders10500_11000_Freight DEFAULT (0),
	ShipName nvarchar (40) NULL ,
	ShipAddress nvarchar (60) NULL ,
	ShipCity nvarchar (15) NULL ,
	ShipRegion nvarchar (15) NULL ,
	ShipPostalCode nvarchar (10) NULL ,
	ShipCountry nvarchar (15) NULL ,
	CONSTRAINT PK_Orders10500_11000 PRIMARY KEY  CLUSTERED 
	(
		OrderID
	),
	CONSTRAINT CK_Orders10500_11000_partition
	CHECK 	(OrderID BETWEEN 10500 AND 11000),
	CONSTRAINT FK_Orders10500_11000_Customers FOREIGN KEY 
	(
		CustomerID
	) REFERENCES Customers (
		CustomerID
	),
	CONSTRAINT FK_Orders10500_11000_Employees FOREIGN KEY 
	(
		EmployeeID
	) REFERENCES Employees (
		EmployeeID
	),
	CONSTRAINT FK_Orders10500_11000_Shippers FOREIGN KEY 
	(
		ShipVia
	) REFERENCES Shippers (
		ShipperID
	)
)
GO

INSERT	dbo.Orders10500_11000
SELECT	*
FROM	dbo.Orders
WHERE	OrderID BETWEEN 10500 AND 11000
GO

IF OBJECT_ID('dbo.Orders11000_11500') IS NOT NULL
DROP TABLE dbo.Orders11000_11500
GO

CREATE TABLE dbo.Orders11000_11500 (
	OrderID int NOT NULL ,
	CustomerID nchar (5) NULL ,
	EmployeeID int NULL ,
	OrderDate datetime NULL ,
	RequiredDate datetime NULL ,
	ShippedDate datetime NULL ,
	ShipVia int NULL ,
	Freight money NULL CONSTRAINT DF_Orders11000_11500_Freight DEFAULT (0),
	ShipName nvarchar (40) NULL ,
	ShipAddress nvarchar (60) NULL ,
	ShipCity nvarchar (15) NULL ,
	ShipRegion nvarchar (15) NULL ,
	ShipPostalCode nvarchar (10) NULL ,
	ShipCountry nvarchar (15) NULL ,
	CONSTRAINT PK_Orders11000_11500 PRIMARY KEY  CLUSTERED 
	(
		OrderID
	),
	CONSTRAINT CK_Orders11000_11500_partition
	CHECK 	(OrderID BETWEEN 11000 AND 11500),
	CONSTRAINT FK_Orders11000_11500_Customers FOREIGN KEY 
	(
		CustomerID
	) REFERENCES Customers (
		CustomerID
	),
	CONSTRAINT FK_Orders11000_11500_Employees FOREIGN KEY 
	(
		EmployeeID
	) REFERENCES Employees (
		EmployeeID
	),
	CONSTRAINT FK_Orders11000_11500_Shippers FOREIGN KEY 
	(
		ShipVia
	) REFERENCES Shippers (
		ShipperID
	)
)
GO

INSERT	dbo.Orders11000_11500
SELECT	*
FROM	dbo.Orders
WHERE	OrderID BETWEEN 11000 AND 11500
GO

/*
** Local Partitioned Views
*/
IF OBJECT_ID('dbo.NewOrders') IS NOT NULL
DROP VIEW dbo.NewOrders
GO

CREATE VIEW dbo.NewOrders
AS
SELECT * FROM dbo.Orders10000_10500
UNION ALL
SELECT * FROM dbo.Orders10500_11000
UNION ALL
SELECT * FROM dbo.Orders11000_11500

GO

SELECT * FROM dbo.NewOrders WHERE OrderID = 10525

SELECT * FROM dbo.NewOrders WHERE OrderDate BETWEEN '1997-01-01' AND '1997-06-01'

/*
** Distributed Partitioned Views
*/
EXEC sp_serveroption 'P456\SQL2000RTM', 'lazy schema validation', 'True'
EXEC sp_serveroption 'P456\SQL2000RTM', 'collation compatible', 'True'
EXEC sp_serveroption 'P456\SQL2000BETA', 'lazy schema validation', 'True'
EXEC sp_serveroption 'P456\SQL2000BETA', 'collation compatible', 'True'

IF OBJECT_ID('dbo.NewOrders') IS NOT NULL
DROP VIEW dbo.NewOrders
GO

CREATE VIEW dbo.NewOrders
AS
SELECT * FROM Northwind.dbo.Orders10000_10500
UNION ALL
SELECT * FROM [P456\SQL2000RTM].Northwind.dbo.Orders10500_11000
UNION ALL
SELECT * FROM [P456\SQL2000BETA].Northwind.dbo.Orders11000_11500

GO

SELECT * FROM dbo.NewOrders WHERE OrderID = 10525
SELECT * FROM dbo.NewOrders WHERE OrderID BETWEEN 10400 AND 10600

SELECT * FROM dbo.NewOrders WHERE OrderDate BETWEEN '1997-01-01' AND '1997-06-01'

/*
** Distributed Partitioned Views
*/
EXEC sp_serveroption 'P456\SQL2000BETA', 'lazy schema validation', 'True'
EXEC sp_serveroption 'P456\SQL2000BETA', 'collation compatible', 'True'
EXEC sp_serveroption 'P456\SQL2000SP', 'lazy schema validation', 'True'
EXEC sp_serveroption 'P456\SQL2000SP', 'collation compatible', 'True'

IF OBJECT_ID('dbo.NewOrders') IS NOT NULL
DROP VIEW dbo.NewOrders
GO

CREATE VIEW dbo.NewOrders
AS
SELECT * FROM [P456\SQL2000SP].Northwind.dbo.Orders10000_10500
UNION ALL
SELECT * FROM Northwind.dbo.Orders10500_11000
UNION ALL
SELECT * FROM [P456\SQL2000BETA].Northwind.dbo.Orders11000_11500

GO

SELECT * FROM dbo.NewOrders WHERE OrderID = 10525
SELECT * FROM dbo.NewOrders WHERE OrderID BETWEEN 10400 AND 10600

SELECT * FROM dbo.NewOrders WHERE OrderDate BETWEEN '1997-01-01' AND '1997-06-01'

/*
** Distributed Partitioned Views
*/
EXEC sp_serveroption 'P456\SQL2000RTM', 'lazy schema validation', 'True'
EXEC sp_serveroption 'P456\SQL2000RTM', 'collation compatible', 'True'
EXEC sp_serveroption 'P456\SQL2000SP', 'lazy schema validation', 'True'
EXEC sp_serveroption 'P456\SQL2000SP', 'collation compatible', 'True'

IF OBJECT_ID('dbo.NewOrders') IS NOT NULL
DROP VIEW dbo.NewOrders
GO

CREATE VIEW dbo.NewOrders
AS
SELECT * FROM [P456\SQL2000SP].Northwind.dbo.Orders10000_10500
UNION ALL
SELECT * FROM [P456\SQL2000RTM].Northwind.dbo.Orders10500_11000
UNION ALL
SELECT * FROM Northwind.dbo.Orders11000_11500

GO

SELECT * FROM dbo.NewOrders WHERE OrderID = 11030
SELECT * FROM dbo.NewOrders WHERE OrderID BETWEEN 10700 AND 11010

SELECT * FROM dbo.NewOrders WHERE OrderDate BETWEEN '1997-01-01' AND '1997-06-01'
