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
-- Synopsis:    Lo scopo di questo script e' di preparare il database della seconda
--              istanza (PSQLCOMPUTE02) per la dimostrazione del partizionamento
-- 				orizzontale dei dati tramite viste partizionate distribuite.
--              
-- 				Modificare i percorsi ed i nomi delle istanze sopra elencati
--				coerentemente con quelli della propria installazione.
-- 				
-- 				Questo script genera il database e le partizioni per gli anni 2004 e
-- 				2006 in carico alla seconda istanza, per generare il database e le
-- 				partizioni della prima istanza utilizzare lo script:
--
-- 				partitioning.it.03.distributed-partitioned-views.01.setup-node1
-- Credits:     
------------------------------------------------------------------------
-- Search/replace paths in this script:
--
-- Default paths:       C:\Temp\demos\partitioning
--                      C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA
-- Default instances:   PSQLCOMPUTE01
--	                    PSQLCOMPUTE02
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Cambiamo contesto.
------------------------------------------------------------------------
USE master;
GO

------------------------------------------------------------------------
-- Aggiungiamo un linked server che punti alla prima istanza
------------------------------------------------------------------------
EXEC	sp_addlinkedserver 'PSQLCOMPUTE01';
GO

------------------------------------------------------------------------
-- creiamo il database di test
------------------------------------------------------------------------
IF EXISTS(SELECT * FROM sysdatabases WHERE name = 'SalesDBDPV')
	DROP DATABASE SalesDBDPV;
GO

CREATE DATABASE SalesDBDPV
ON PRIMARY (
	NAME		= 'SalesDBDPV_mdf'
,	FILENAME	= 'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\SalesDBDPV.mdf'
,	SIZE		= 10MB
,	MAXSIZE		= 50MB
,	FILEGROWTH	= 10MB
)
LOG ON (
	NAME		= 'SalesDBDPV_log'
,	FILENAME	= 'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\SalesDBDPV.ldf'
,	SIZE		= 10MB
,	MAXSIZE		= 500MB
,	FILEGROWTH	= 100MB
);
GO

------------------------------------------------------------------------
-- Cambiamo contesto.
------------------------------------------------------------------------
USE SalesDBDPV;
GO

------------------------------------------------------------------------
-- Modifichiamo il recovery model per effettuare il caricamento
-- in modalita' bulk copy ad alte prestazioni.
------------------------------------------------------------------------
ALTER DATABASE SalesDBDPV SET RECOVERY SIMPLE;
GO

------------------------------------------------------------------------
-- Aggiungiamo un filegroup per la partizione che conterra' la tabella
-- con i dati dell'anno 2004.
------------------------------------------------------------------------
ALTER DATABASE	SalesDBDPV
ADD FILEGROUP	ORDERS2004;
GO

------------------------------------------------------------------------
-- Aggiungiamo un file al filegroup.
------------------------------------------------------------------------
ALTER DATABASE	SalesDBDPV
ADD FILE (
	NAME		= 'SalesDBDPV_orders2004'
,	FILENAME	= 'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\SalesDBDPV_orders2004.ndf'
,	SIZE		= 100MB
,	MAXSIZE		= 150MB
,	FILEGROWTH	= 10MB
)
TO FILEGROUP ORDERS2004;
GO

------------------------------------------------------------------------
-- Creiamo la tabella che conterra' i dati del 2004.
------------------------------------------------------------------------
CREATE TABLE dbo.Orders2004
(
	OrderID		int			NOT NULL
,	CustomerID	char(11)	NOT NULL
,	EmployeeID	int			NOT NULL
,	ShipperID	varchar(5)	NOT NULL
,	OrderDate	datetime	NOT NULL
,	Filler		char(155)	NOT NULL
) ON ORDERS2004;
GO

------------------------------------------------------------------------
-- Carichiamo i dati della partizione.
------------------------------------------------------------------------
BULK INSERT	dbo.Orders2004
FROM		'C:\Temp\demos\partitioning\00.dati-Orders-2004.txt'
WITH	(
			FORMATFILE = 'C:\Temp\demos\partitioning\00.dati-Orders.fmt'
,			TABLOCK
	);
GO

------------------------------------------------------------------------
-- Creiamo la chiave primaria ed il check constraint.
------------------------------------------------------------------------
ALTER TABLE dbo.Orders2004
ADD	CONSTRAINT	PK_Orders2004
	PRIMARY KEY	(OrderDate, OrderID)
	ON			ORDERS2004;
GO

ALTER TABLE dbo.Orders2004
ADD	CONSTRAINT	CK_Orders2004RangeYear
	CHECK		(OrderDate >= '20040101' 
			AND OrderDate < '20050101');
GO

------------------------------------------------------------------------
-- Aggiungiamo un filegroup per la partizione che conterra' la tabella
-- con i dati dell'anno 2006.
------------------------------------------------------------------------
ALTER DATABASE	SalesDBDPV
ADD FILEGROUP	ORDERS2006;
GO

------------------------------------------------------------------------
-- Aggiungiamo un file al filegroup.
------------------------------------------------------------------------
ALTER DATABASE	SalesDBDPV
ADD FILE (
	NAME		= 'SalesDBDPV_orders2006'
,	FILENAME	= 'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\SalesDBDPV_orders2006.ndf'
,	SIZE		= 100MB
,	MAXSIZE		= 150MB
,	FILEGROWTH	= 10MB
)
TO FILEGROUP ORDERS2006;
GO

------------------------------------------------------------------------
-- Creiamo la tabella che conterra' i dati del 2006.
------------------------------------------------------------------------
CREATE TABLE dbo.Orders2006
(
	OrderID		int			NOT NULL
,	CustomerID	char(11)	NOT NULL
,	EmployeeID	int			NOT NULL
,	ShipperID	varchar(5)	NOT NULL
,	OrderDate	datetime	NOT NULL
,	Filler		char(155)	NOT NULL
) ON ORDERS2006;
GO

------------------------------------------------------------------------
-- Carichiamo i dati della partizione.
------------------------------------------------------------------------
BULK INSERT	dbo.Orders2006
FROM		'C:\Temp\demos\partitioning\00.dati-Orders-2006.txt'
WITH	(
			FORMATFILE = 'C:\Temp\demos\partitioning\00.dati-Orders.fmt'
,			TABLOCK
	);
GO

------------------------------------------------------------------------
-- Creiamo la chiave primaria ed il check constraint.
------------------------------------------------------------------------
ALTER TABLE dbo.Orders2006
ADD	CONSTRAINT	PK_Orders2006
	PRIMARY KEY	(OrderDate, OrderID)
	ON			ORDERS2006;
GO

ALTER TABLE dbo.Orders2006
ADD	CONSTRAINT	CK_Orders2006RangeYear
	CHECK		(OrderDate >= '20060101' 
			AND OrderDate < '20070101');
GO

------------------------------------------------------------------------
-- Prima di creare la vista, assicurarsi di aver eseguito lo script che
-- preparara il database per la prima istanza.
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Creiamo la vista che ricostruisce la relazione originale.
------------------------------------------------------------------------
CREATE VIEW dbo.Orders
AS

SELECT	* FROM [PSQLCOMPUTE01].SalesDBDPV.dbo.Orders2003
UNION ALL
SELECT	* FROM dbo.Orders2004
UNION ALL
SELECT	* FROM [PSQLCOMPUTE01].SalesDBDPV.dbo.Orders2005
UNION ALL
SELECT	* FROM dbo.Orders2006

GO

------------------------------------------------------------------------
-- Ricordarsi di creare la vista anche per il database della prima
-- istanza.
------------------------------------------------------------------------
