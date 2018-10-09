------------------------------------------------------------------------
-- Script:		sparse-columns.sql
-- Copyright:	2012 Gianluca Hotz
-- License:		MIT License
-- Credits:		
------------------------------------------------------------------------------------------------------------------------------------------------
USE tempdb;
GO

------------------------------------------------------------------------
-- Let's first build a common solution that uses a technique
-- similar to EAV (Entity Attribute Value).
------------------------------------------------------------------------
IF OBJECT_ID('dbo.Product', 'U') IS NOT NULL
	DROP TABLE dbo.Product;
GO

CREATE TABLE dbo.Product (
	ProductID		int				NOT NULL
,	ProductType		varchar(255)	NOT NULL
,	ProductName		varchar(1000)	NOT NULL

,	CONSTRAINT		pkProduct
	PRIMARY KEY		(ProductID)
);
GO

IF OBJECT_ID('dbo.ProductEAV', 'U') IS NOT NULL
	DROP TABLE dbo.ProductEAV;
GO

CREATE TABLE dbo.ProductEAV (
	ProductID				int				NOT NULL
,	ProductPropertyName		varchar(256)	NOT NULL
,	ProductPropertyValue	varchar(256)	NOT NULL

,	CONSTRAINT		pkProductEAV
	PRIMARY KEY		(ProductID, ProductPropertyName)
);
GO

------------------------------------------------------------------------
-- We insert some sample data 
------------------------------------------------------------------------
SET NOCOUNT ON;
GO

INSERT	dbo.Product		VALUES (1, 'Camera', 'Olympus E1');
INSERT	dbo.ProductEAV	VALUES (1, 'CameraFormat', 'SLR');
INSERT	dbo.ProductEAV	VALUES (1, 'Resolution', '5');

INSERT	dbo.Product		VALUES (2, 'Camera', 'Olympus 8080WZ');
INSERT	dbo.ProductEAV	VALUES (2, 'CameraFormat', 'SLR-like');
INSERT	dbo.ProductEAV	VALUES (2, 'Resolution', '8');
INSERT	dbo.ProductEAV	VALUES (2, 'Zoom Wide (mm)', '28');
INSERT	dbo.ProductEAV	VALUES (2, 'Zoom Tele (mm)', '140');

INSERT	dbo.Product		VALUES (3, 'Camera', 'Sony Cyber-shot DSC-P200');
INSERT	dbo.ProductEAV	VALUES (3, 'CameraFormat', 'Compact');
INSERT	dbo.ProductEAV	VALUES (3, 'Resolution', '7');
INSERT	dbo.ProductEAV	VALUES (3, 'Zoom Wide (mm)', '38');
INSERT	dbo.ProductEAV	VALUES (3, 'Zoom Tele (mm)', '144');

INSERT	dbo.Product		VALUES (4, 'Memory Card', 'SanDisk 2GB SD Memory Card');
INSERT	dbo.ProductEAV	VALUES (4, 'Memory card type', 'SD');
INSERT	dbo.ProductEAV	VALUES (4, 'Storage Size (GB)', '2');

INSERT	dbo.Product		VALUES (5, 'Memory Card', 'SanDisk 4GB MicroSDHC Memory Card');
INSERT	dbo.ProductEAV	VALUES (5, 'Memory card type', 'MicroSDHC');
INSERT	dbo.ProductEAV	VALUES (5, 'Storage Size (GB)', '4');

INSERT	dbo.Product		VALUES (6, 'Mobile Phone', 'HTC TyTN II');
INSERT	dbo.ProductEAV	VALUES (6, 'ROM Size (MB)', '256');
INSERT	dbo.ProductEAV	VALUES (6, 'RAM Size (MB)', '128');

INSERT	dbo.Product		VALUES (7, 'Mobile Phone', 'Asus P320');
INSERT	dbo.ProductEAV	VALUES (7, 'ROM Size (MB)', '128');
INSERT	dbo.ProductEAV	VALUES (7, 'RAM Size (MB)', '64');
GO
SET NOCOUNT OFF;
GO

------------------------------------------------------------------------
-- A common problem when pivoting data because you can't
-- dynamically create the set of properties to be transformed
-- in columns by the PIVOT operator.
--
-- I.e. for every new property you want to handle, you must change
-- the query to include that property name.
--
-- Another problem is that you can't specify appropriate data types
-- for each property.
------------------------------------------------------------------------
SELECT
	P1.ProductID
,	P1.ProductName
,	P1.ProductType
,	P2.ProductPropertyName
,	P2.ProductPropertyValue
FROM	dbo.Product AS P1
JOIN	dbo.ProductEAV AS P2
  ON	P1.ProductID = P2.ProductID;

WITH Products AS
(  
	SELECT
		P1.ProductID
	,	P1.ProductName
	,	P1.ProductType
	,	P2.ProductPropertyName
	,	P2.ProductPropertyValue
	FROM	dbo.Product AS P1
	JOIN	dbo.ProductEAV AS P2
	  ON	P1.ProductID = P2.ProductID
 )
 SELECT	*
 FROM	Products AS P1
 PIVOT	(
		MAX(ProductPropertyValue)
		FOR ProductPropertyName IN	(
			[CameraFormat], [Resolution], [Zoom Wide (mm)], [Zoom Tele (mm)]
		,	[Memory card type], [Storage Size (GB)], [ROM Size (MB)], [RAM Size (MB)]
		)
	) AS P2;
GO
--------------------------------------------------------
-- Let's see how we can handle the problem with sparse columns.
------------------------------------------------------------------------
IF OBJECT_ID('dbo.Product', 'U') IS NOT NULL
	DROP TABLE dbo.Product;
GO

CREATE TABLE dbo.Product (
	ProductID		int				NOT NULL
,	ProductType		varchar(255)	NOT NULL
,	ProductName		varchar(1000)	NOT NULL
	
,	CameraFormat		varchar(256)	SPARSE NULL
,	Resolution			int				SPARSE NULL
	CHECK (Resolution > 1)				-- just one as an example
,	[Zoom Wide (mm)]	int				SPARSE NULL
,	[Zoom Tele (mm)]	int				SPARSE NULL
,	[Memory card type]	varchar(256)	SPARSE NULL
,	[Storage Size (GB)]	int				SPARSE NULL
,	[ROM Size (MB)]		int				SPARSE NULL
,	[RAM Size (MB)]		int				SPARSE NULL

,	CONSTRAINT		pkProduct
	PRIMARY KEY		(ProductID)
);
GO

------------------------------------------------------------------------
-- We insert some sample data 
------------------------------------------------------------------------
INSERT	dbo.Product
VALUES
	(1, 'Camera', 'Olympus E1','SLR',5,NULL,NULL,NULL,NULL,NULL,NULL)
,	(2, 'Camera', 'Olympus 8080WZ','SLR-like',8,28,140,NULL,NULL,NULL,NULL)
,	(3, 'Camera', 'Sony Cyber-shot DSC-P200','Compact',7,38,144,NULL,NULL,NULL,NULL)
,	(4, 'Memory Card', 'SanDisk 2GB SD Memory Card',NULL,NULL,NULL,NULL,'SD',2,NULL,NULL)
,	(5, 'Memory Card', 'SanDisk 4GB MicroSDHC Memory Card',NULL,NULL,NULL,NULL,'MicroSDHC',4,NULL,NULL)
,	(6,	'Mobile Phone', 'HTC TyTN II',NULL,NULL,NULL,NULL,NULL,NULL,256,128)
,	(7, 'Mobile Phone', 'Asus P320',NULL,NULL,NULL,NULL,NULL,NULL,128,64);
GO

------------------------------------------------------------------------
-- Now we don't need to pivot and if we do select all columns (which is
-- not recommended) the columns are now dinamycally included.
--
-- Still the client application would need to parse them.
------------------------------------------------------------------------
SELECT	*
FROM	dbo.Product;
GO

------------------------------------------------------------------------
-- To facilitate client side development, we can add a column set
------------------------------------------------------------------------
ALTER TABLE dbo.Product 
ADD AllPropertiesCS	XML COLUMN_SET FOR ALL_SPARSE_COLUMNS;
GO

------------------------------------------------------------------------
-- Unfortunately we cannot add it, we have to think about it in
-- advance when creating the table.
------------------------------------------------------------------------
IF OBJECT_ID('dbo.Product', 'U') IS NOT NULL
	DROP TABLE dbo.Product;
GO

CREATE TABLE dbo.Product (
	ProductID		int				NOT NULL
,	ProductType		varchar(255)	NOT NULL
,	ProductName		varchar(1000)	NOT NULL
	
,	CameraFormat		varchar(256)	SPARSE NULL
,	Resolution			int				SPARSE NULL
	CHECK (Resolution > 1)				-- just one as an example
,	[Zoom Wide (mm)]	int				SPARSE NULL
,	[Zoom Tele (mm)]	int				SPARSE NULL
,	[Memory card type]	varchar(256)	SPARSE NULL
,	[Storage Size (GB)]	int				SPARSE NULL
,	[ROM Size (MB)]		int				SPARSE NULL
,	[RAM Size (MB)]		int				SPARSE NULL

,	AllPropertiesCS		XML COLUMN_SET
						FOR ALL_SPARSE_COLUMNS

,	CONSTRAINT		pkProduct
	PRIMARY KEY		(ProductID)
);
GO

INSERT	dbo.Product (ProductID, ProductType, ProductName
		, CameraFormat, Resolution, [Zoom Wide (mm)], [Zoom Tele (mm)]
		, [Memory card type], [Storage Size (GB)], [ROM Size (MB)]
		, [RAM Size (MB)]
		)
VALUES
	(1, 'Camera', 'Olympus E1','SLR',5,NULL,NULL,NULL,NULL,NULL,NULL)
,	(2, 'Camera', 'Olympus 8080WZ','SLR-like',8,28,140,NULL,NULL,NULL,NULL)
,	(3, 'Camera', 'Sony Cyber-shot DSC-P200','Compact',7,38,144,NULL,NULL,NULL,NULL)
,	(4, 'Memory Card', 'SanDisk 2GB SD Memory Card',NULL,NULL,NULL,NULL,'SD',2,NULL,NULL)
,	(5, 'Memory Card', 'SanDisk 4GB MicroSDHC Memory Card',NULL,NULL,NULL,NULL,'MicroSDHC',4,NULL,NULL)
,	(6,	'Mobile Phone', 'HTC TyTN II',NULL,NULL,NULL,NULL,NULL,NULL,256,128)
,	(7, 'Mobile Phone', 'Asus P320',NULL,NULL,NULL,NULL,NULL,NULL,128,64);
GO

------------------------------------------------------------------------
-- Now the application can select the common attributes and the
-- column set directly by selecting all columns (although this is
-- not the recommended way).
------------------------------------------------------------------------
SELECT	*
FROM	dbo.Product;
GO

------------------------------------------------------------------------
-- Of couse we can still access both sparse and non sparse columns.
------------------------------------------------------------------------
SELECT
	P1.ProductID
,	P1.ProductName
,	P1.[Memory card type]
,	P1.[Storage Size (GB)]
FROM	dbo.Product AS P1
WHERE	P1.ProductType = 'Memory card';
GO

------------------------------------------------------------------------
-- Columns can be updated as usual, but also through column sets.
------------------------------------------------------------------------
UPDATE	dbo.Product
SET		[RAM Size (MB)] = 128
WHERE	ProductID = 7;
GO

UPDATE	dbo.Product
SET		AllPropertiesCS = '<ROM_x0020_Size_x0020__x0028_MB_x0029_>256</ROM_x0020_Size_x0020__x0028_MB_x0029_>
<RAM_x0020_Size_x0020__x0028_MB_x0029_>256</RAM_x0020_Size_x0020__x0028_MB_x0029_>'
WHERE	ProductID = 6;
GO

SELECT
	P1.ProductID
,	P1.ProductName
,	P1.[ROM Size (MB)]
,	P1.[RAM Size (MB)]
FROM	dbo.Product AS P1
WHERE	P1.ProductType = 'Mobile phone';
GO

