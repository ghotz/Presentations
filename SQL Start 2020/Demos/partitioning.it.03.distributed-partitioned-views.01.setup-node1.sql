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
-- Synopsis:    Lo scopo di questo script e' di preparare il database della prima
--              istanza (PSQLCOMPUTE01) per la dimostrazione del partizionamento
-- 				orizzontale dei dati tramite viste partizionate distribuite.
--              
-- 				Modificare i percorsi ed i nomi delle istanze sopra elencati
--				coerentemente con quelli della propria installazione.
-- 				
-- 				Questo script genera il database e le partizioni per gli anni 2003 e
-- 				2005 in carico alla prima istanza, per generare il database e le
-- 				partizioni della seconda istanza utilizzare lo script:
-- 				partitioning.it.03.distributed-partitioned-views.02.setup-node2
-- Credits:     
------------------------------------------------------------------------
-- Search/replace paths in this script:
--
-- Default paths:       C:\Temp\Demos\Partitioning
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
-- Aggiungiamo un linked server che punti alla seconda istanza
------------------------------------------------------------------------
EXEC	sp_addlinkedserver 'PSQLCOMPUTE02';
GO

------------------------------------------------------------------------
-- creiamo il database di test
------------------------------------------------------------------------
IF EXISTS(SELECT * FROM sys.databases WHERE name = 'SalesDBDPV')
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
-- con i dati dell'anno 2003.
------------------------------------------------------------------------
ALTER DATABASE	SalesDBDPV
ADD FILEGROUP	ORDERS2003;
GO

------------------------------------------------------------------------
-- Aggiungiamo un file al filegroup.
------------------------------------------------------------------------
ALTER DATABASE	SalesDBDPV
ADD FILE (
	NAME		= 'SalesDBDPV_orders2003'
,	FILENAME	= 'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\SalesDBDPV_orders2003.ndf'
,	SIZE		= 100MB
,	MAXSIZE		= 150MB
,	FILEGROWTH	= 10MB
)
TO FILEGROUP ORDERS2003;
GO

------------------------------------------------------------------------
-- Creiamo la tabella che conterra' i dati del 2003.
------------------------------------------------------------------------
CREATE TABLE dbo.Orders2003
(
	OrderID		int			NOT NULL
,	CustomerID	char(11)	NOT NULL
,	EmployeeID	int			NOT NULL
,	ShipperID	varchar(5)	NOT NULL
,	OrderDate	datetime	NOT NULL
,	Filler		char(155)	NOT NULL
) ON ORDERS2003;
GO

------------------------------------------------------------------------
-- Carichiamo i dati della partizione senza indici per avere il massimo
-- delle prestazioni e tracciare il minimo indispensabile nel
-- transaction log.
--
-- Il prezzo da pagare e' che per aggiungere successivamente l'indice
-- clustered, dovremo disporre di circa 1.2 volte lo spazio occupato
-- dalla tabella durante la creazione.
-- 
-- In alternativa, se il file e' ordinato per le colonne che compongono
-- l'indice clustered, e' possibile caricare sempre tracciando il minimo
-- indispensabile nel transaction log con un degrado minimo delle
-- prestazioni, utilizzando l'hint ORDER (OrderDate, ShipperID) con il
-- comando di inserimento bulk.
------------------------------------------------------------------------
BULK INSERT	dbo.Orders2003
FROM		'C:\Temp\Demos\Partitioning\00.dati-Orders-2003.txt'
WITH	(
			FORMATFILE = 'C:\Temp\Demos\Partitioning\00.dati-Orders.fmt'
,			TABLOCK
		);
GO

------------------------------------------------------------------------
-- Fondamendali sono:
-- 1) la chiave primaria, che deve includere la colonna di
-- partizionamento perche' la vista sia aggiornabile; in alternativa
-- si possono creare degli INSTEAD OF trigger per renderla comunque
-- aggiornabile (ma e' meno pratico);
-- 2) il CHECK constraint, che definische il range di valori della
-- partizione e che server al Query Optimizer per sfruttare la tecnica
-- della "partition elimination" e cioe' di accedere solo alle tabelle
-- effettivamente interessate dalla query (altrimenti sarebbe necessario
-- fare comunque sempre una scansione di tutte le tabelle).
------------------------------------------------------------------------
ALTER TABLE dbo.Orders2003
ADD	CONSTRAINT	PK_Orders2003
	PRIMARY KEY	(OrderDate, OrderID)
	ON			ORDERS2003;
GO

ALTER TABLE dbo.Orders2003
ADD	CONSTRAINT	CK_Orders2003RangeYear
	CHECK		(OrderDate >= '20030101' 
			AND OrderDate < '20040101');
GO

------------------------------------------------------------------------
-- Aggiungiamo un filegroup per la partizione che conterra' la tabella
-- con i dati dell'anno 2005.
------------------------------------------------------------------------
ALTER DATABASE	SalesDBDPV
ADD FILEGROUP	ORDERS2005;
GO

------------------------------------------------------------------------
-- Aggiungiamo un file al filegroup.
------------------------------------------------------------------------
ALTER DATABASE	SalesDBDPV
ADD FILE (
	NAME		= 'SalesDBDPV_orders2005'
,	FILENAME	= 'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\SalesDBDPV_orders2005.ndf'
,	SIZE		= 100MB
,	MAXSIZE		= 150MB
,	FILEGROWTH	= 10MB
)
TO FILEGROUP ORDERS2005;
GO

------------------------------------------------------------------------
-- Creiamo la tabella che conterra' i dati del 2005.
------------------------------------------------------------------------
CREATE TABLE dbo.Orders2005
(
	OrderID		int			NOT NULL
,	CustomerID	char(11)	NOT NULL
,	EmployeeID	int			NOT NULL
,	ShipperID	varchar(5)	NOT NULL
,	OrderDate	datetime	NOT NULL
,	Filler		char(155)	NOT NULL
) ON ORDERS2005;
GO

------------------------------------------------------------------------
-- Carichiamo i dati della partizione.
------------------------------------------------------------------------
BULK INSERT	dbo.Orders2005
FROM		'C:\Temp\Demos\Partitioning\00.dati-Orders-2005.txt'
WITH	(
			FORMATFILE = 'C:\Temp\Demos\Partitioning\00.dati-Orders.fmt'
,			TABLOCK
		);
GO

------------------------------------------------------------------------
-- Creiamo la chiave primaria ed il check constraint.
------------------------------------------------------------------------
ALTER TABLE dbo.Orders2005
ADD	CONSTRAINT	PK_Orders2005
	PRIMARY KEY	(OrderDate, OrderID)
	ON			ORDERS2005;
GO

ALTER TABLE dbo.Orders2005
ADD	CONSTRAINT	CK_Orders2005RangeYear
	CHECK		(OrderDate >= '20050101' 
			AND OrderDate < '20060101');
GO

------------------------------------------------------------------------
-- Prima di creare la vista, eseguire lo script che preparara il
-- database per la seconda istanza.
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Creiamo la vista che ricostruisce la relazione originale.
------------------------------------------------------------------------
CREATE VIEW dbo.Orders
AS

SELECT	* FROM dbo.Orders2003
UNION ALL
SELECT	* FROM [PSQLCOMPUTE02].SalesDBDPV.dbo.Orders2004
UNION ALL
SELECT	* FROM dbo.Orders2005
UNION ALL
SELECT	* FROM [PSQLCOMPUTE02].SalesDBDPV.dbo.Orders2006

GO

------------------------------------------------------------------------
-- Ricordarsi di creare la vista anche per il database della seconda
-- istanza.
------------------------------------------------------------------------

