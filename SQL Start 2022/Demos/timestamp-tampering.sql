USE tempdb
DROP TABLE IF EXISTS dbo.Table1;
CREATE TABLE dbo.Table1 (
	Field1 int			NOT NULL PRIMARY KEY
,	Field2 varchar(20)	NOT NULL
,	Field3 timestamp
);
INSERT	dbo.Table1 (Field1, Field2)
VALUES	(1, 'Original 1'),(2, 'Original 2'),(3, 'Original 3');

SELECT * FROM dbo.Table1;
GO

-- Tamper by modifying value but keeping original timestamp/rowversion
DROP TABLE IF EXISTS dbo.Table2;
SELECT
		Field1
,		CASE WHEN Field1 = 2 THEN 'Modified 2' ELSE Field2 END Field2
,		Field3
INTO	dbo.Table2
FROM	dbo.Table1;

-- Show tampered data
SELECT
		T1.Field1
,		T1.Field2 AS Field2_original
,		T2.Field2 AS Field2_tampered
,		T1.Field3 AS Field3_original
,		T2.Field3 AS Field3_tampered
FROM	dbo.Table1 AS T1
JOIN	dbo.Table2 AS T2
  ON	T1.Field1 = T2.Field1;
GO

-- at this point you rename the tables and you're done

-- Tamper by pretending the value was inserted chronologically at a later time
DROP TABLE IF EXISTS dbo.Table2;
SELECT
		Field1
,		Field2
,		CASE WHEN Field1 = 2
		THEN CAST((SELECT MAX(Field3) FROM dbo.Table1) + 1 AS timestamp)
		ELSE Field3
		END AS Field3
INTO	dbo.Table2
FROM	dbo.Table1;

-- Show tampered data
SELECT
		T1.Field1
,		T1.Field2 AS Field2_original
,		T2.Field2 AS Field2_tampered
,		T1.Field3 AS Field3_original
,		T2.Field3 AS Field3_tampered
FROM	dbo.Table1 AS T1
JOIN	dbo.Table2 AS T2
  ON	T1.Field1 = T2.Field1;
GO
