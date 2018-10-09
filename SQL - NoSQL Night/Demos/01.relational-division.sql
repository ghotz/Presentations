------------------------------------------------------------------------
-- Script:		relational-division.sql
-- Copyright:	2018 Gianluca Hotz
-- License:		MIT License
-- Credits:		https://www.slideshare.net/davidemauri/schema-less-table-dynamic-schema-44295422
--				https://social.technet.microsoft.com/wiki/contents/articles/22165.t-sql-relational-division.aspx
--				https://www.red-gate.com/simple-talk/sql/learn-sql-server/high-performance-relational-division-in-sql-server
------------------------------------------------------------------------
USE [AdventureWorks2017]
GO

-- Vogliamo vedere se questi prodotti vengono comprati insieme
SELECT	*
FROM	Production.Product
WHERE	ProductNumber IN ('PK-7098', 'TT-M928');
GO

-- Divisone semplice con resto (ordini con quei due prodotti ma anche altri)
SELECT	O1.SalesOrderID
FROM	Sales.SalesOrderDetail AS O1
JOIN	(
		SELECT	P1.ProductID
		FROM	Production.Product AS P1
		WHERE	P1.ProductNumber IN ('PK-7098', 'TT-M928')
		) AS T1
  ON	O1.ProductID = T1.ProductID
GROUP BY
		O1.SalesOrderID
HAVING	COUNT(O1.ProductID) = (
			SELECT	COUNT(P2.ProductID)
			FROM	Production.Product AS P2
			WHERE	P2.ProductNumber IN ('PK-7098', 'TT-M928')
		);
GO

-- Verifichiamo (873, 921)
SELECT * FROM Sales.SalesOrderDetail WHERE SalesOrderID = 51217;
GO

-- può anche essere riscritta con una CTE per chiarezza
WITH cte AS
(
	SELECT	P1.ProductID
	FROM	Production.Product AS P1
	WHERE	P1.ProductNumber IN ('PK-7098', 'TT-M928')
)
SELECT	O1.SalesOrderID
FROM	Sales.SalesOrderDetail AS O1
JOIN	cte AS T1
  ON	O1.ProductID = T1.ProductID
GROUP BY
		O1.SalesOrderID
HAVING	COUNT(O1.ProductID) = (SELECT COUNT(P2.ProductID) FROM cte AS P2);
GO

-- e la JOIN sostituita con WHERE/IN
-- notare che il piano di esecuzione non cambia
WITH cte AS
(
	SELECT	P1.ProductID
	FROM	Production.Product AS P1
	WHERE	P1.ProductNumber IN ('PK-7098', 'TT-M928')
)
SELECT	O1.SalesOrderID
FROM	Sales.SalesOrderDetail AS O1
WHERE	O1.ProductID IN (SELECT P3.ProductID FROM cte AS P3)
GROUP BY
		O1.SalesOrderID
HAVING	COUNT(O1.ProductID) = (SELECT COUNT(P2.ProductID) FROM cte AS P2);
GO

-- divisone senza resto (ordini che contengono *solo* quei due prodotti) 
WITH cte AS
(
	SELECT	P1.ProductID
	FROM	Production.Product AS P1
	WHERE	P1.ProductNumber IN ('PK-7098', 'TT-M928')
)
SELECT	O1.SalesOrderID
FROM	Sales.SalesOrderDetail AS O1
WHERE	O1.ProductID IN (SELECT P3.ProductID FROM cte AS P3)
GROUP BY
		O1.SalesOrderID
HAVING	COUNT(DISTINCT O1.ProductID) = (SELECT COUNT(P2.ProductID) FROM cte AS P2)
  AND	COUNT(DISTINCT O1.ProductID) = (SELECT COUNT(*) FROM Sales.SalesOrderDetail AS O2 WHERE O1.SalesOrderID = O2.SalesOrderID);
GO

-- Verifichiamo
SELECT * FROM Sales.SalesOrderDetail WHERE SalesOrderID = 51948;
GO

-- Trovare tutti gli ordini con prodotti simili ordinati (> 1mio combinazioni ritornate)
-- (versione Joe Celko: 1 minuto con Xeon E3-1505M v6 8 core @ 3GHz con 64GB RAM)
SELECT
	O1.SalesOrderId AS OrderID
,	O2.SalesOrderID AS SimilarOrderID
FROM	Sales.SalesOrderDetail O1
JOIN	Sales.SalesOrderDetail O2
  ON	O1.ProductID = O2.ProductID
 AND	O1.SalesOrderID < O2.SalesOrderID
GROUP BY
		O1.SalesOrderID, O2.SalesOrderID
HAVING COUNT(O1.ProductID) = (
		SELECT	COUNT(ProductID)
		FROM	Sales.SalesOrderDetail SD1
		WHERE	SD1.SalesOrderID = O1.SalesOrderID
        )
    AND COUNT(O2.ProductID) = (
		SELECT	COUNT(ProductID)
		FROM	Sales.SalesOrderDetail SD2
		WHERE	SD2.SalesOrderID = O2.SalesOrderID
        );
GO

-- Trovare tutti gli ordini con prodotti simili ordinati (> 1mio combinazioni ritornate)
-- (versione Peter Larsson: 8 secondi con Xeon E3-1505M v6 8 core @ 3GHz con 64GB RAM)
SELECT
	t1.SalesOrderID AS OrderID
,	t2.SalesOrderID AS SimilarOrderID
FROM	(
		SELECT
				SalesOrderID
        ,		COUNT(*) AS Items
        ,		MIN(ProductID) AS minProdID
        ,		MAX(ProductID) AS maxProdID
		FROM	Sales.SalesOrderDetail
		GROUP BY
				SalesOrderID
		) AS v
JOIN	Sales.SalesOrderDetail AS t1
  ON	t1.SalesOrderID = v.SalesOrderID
JOIN	Sales.SalesOrderDetail AS t2
  ON	t2.ProductID = t1.ProductID
 AND	t2.SalesOrderID > t1.SalesOrderID
JOIN	(
		SELECT
			SalesOrderID
        ,	COUNT(*) AS Items
        ,	MIN(ProductID) AS minProdID
        ,	MAX(ProductID) AS maxProdID
		FROM	Sales.SalesOrderDetail
		GROUP BY
			SalesOrderID
		) AS w
   ON	w.SalesOrderID = t2.SalesOrderID
WHERE	w.minProdID = v.minProdID
  AND	w.maxProdID = v.maxProdID
  AND	w.Items = v.Items
GROUP BY
	t1.SalesOrderID
,	t2.SalesOrderID
HAVING COUNT(*) = MIN(v.Items);
GO

-- Trovare tutti gli ordini con prodotti simili ordinati (> 1mio combinazioni ritornate)
-- (versione con materializzazione lista prodotti in XML: 10 secondi con Xeon E3-1505M v6 8 core @ 3GHz con 64GB RAM)
WITH cte AS
(
	SELECT
		SalesOrderID
	,	STUFF((
			SELECT	', ' + CAST(ProductID AS VARCHAR(max))
			FROM	Sales.SalesOrderDetail SD1
			WHERE	SD1.SalesOrderID = SD.SalesOrderID
			ORDER BY ProductID
			FOR XML PATH('')
		), 1, 2, '') AS Products
    FROM Sales.SalesOrderDetail SD
    GROUP BY SD.SalesOrderID
)
SELECT
	cte.SalesOrderID AS OrderID
,	cte1.SalesOrderID AS SimilarOrderID
,	cte.Products
FROM	cte
JOIN	cte AS cte1
  ON	cte.SalesOrderID < cte1.SalesOrderID
 AND	cte.Products = cte1.Products;
 GO

 -- Trovare tutti gli ordini con prodotti simili ordinati (> 1mio combinazioni ritornate)
-- (versione senza trucco XML in 2017: 8 secondi con Xeon E3-1505M v6 8 core @ 3GHz con 64GB RAM)
 WITH cte AS
(
	SELECT
		SalesOrderID
	,	STRING_AGG(ProductID, ',') AS Products
    FROM Sales.SalesOrderDetail SD
    GROUP BY SD.SalesOrderID
)
SELECT
	cte.SalesOrderID AS OrderID
,	cte1.SalesOrderID AS SimilarOrderID
,	cte.Products
FROM	cte
JOIN	cte AS cte1
  ON	cte.SalesOrderID < cte1.SalesOrderID
 AND	cte.Products = cte1.Products;
 GO