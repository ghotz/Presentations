------------------------------------------------------------------------
-- Script:		sql2017-t-sql-development.sql
-- Copyright:	2017 Gianluca Hotz
-- License:		MIT License
-- Credits:
------------------------------------------------------------------------

------------------------------------------------------------------------
-- CONCAT_WS
------------------------------------------------------------------------

-- Concatenating values with separator
SELECT	CONCAT_WS( ' - ', DB_NAME(D1.database_id), D1.recovery_model_desc, D1.containment_desc) AS DatabaseInfo
FROM	sys.databases AS D1;
GO

-- Skipping NULL values
SELECT CONCAT_WS(',','1 Microsoft Way', NULL, NULL, 'Redmond', 'WA', 98052) AS [Address];
GO

-- Fast wayt to generate CSV file from table but beware of NULLs
SELECT	CONCAT_WS(',', Title, FirstName, MiddleName, LastName) AS FullName
FROM	AdventureWorks2017.Person.Person;
GO
SELECT	CONCAT_WS(',', ISNULL(Title,''), FirstName, ISNULL(MiddleName,''), LastName) AS FullName
FROM	AdventureWorks2017.Person.Person;
GO

------------------------------------------------------------------------
-- TRANSLATE
------------------------------------------------------------------------

-- replace braces equivalent to SELECT REPLACE(REPLACE(REPLACE(REPLACE('2*[3+4]/{7-2}','[','('), ']', ')'), '{', '('), '}', ')');
SELECT TRANSLATE('2*[3+4]/{7-2}', '[]{}', '()()');
GO

-- Convert GeoJSON points into WKT
SELECT
	TRANSLATE('[137.4, 72.3]' , '[,]', '( )') AS Point
,	TRANSLATE('(137.4 72.3)' , '( )', '[,]') AS Coordinates;
GO

------------------------------------------------------------------------
-- TRIM
------------------------------------------------------------------------

-- basic example removing spaces
SELECT '>' + TRIM( '     test    ') + '<' AS Result;
GO

-- removing specific set of characters
SELECT '>' + TRIM('.,! ' FROM '#     test    .') + '<' AS Result;
GO

------------------------------------------------------------------------
-- STRING_AGG
------------------------------------------------------------------------

-- basic example aggregating names starting with Z
SELECT	STRING_AGG(FirstName, ',') NamesList
FROM	AdventureWorks2017.Person.Person
WHERE	FirstName LIKE 'Z%';
GO

-- with names starting with A we are already hitting limits, beware as this is a runtime error!
SELECT	STRING_AGG(FirstName, ',') NamesList
FROM	AdventureWorks2017.Person.Person
WHERE	FirstName LIKE 'A%';
GO

-- we need to cast the data type, not necessarily a best practice... (think at performance and runaway queries)
SELECT	STRING_AGG(CAST(FirstName AS NVARCHAR(MAX)), ',') NamesList
FROM	AdventureWorks2017.Person.Person
WHERE	FirstName LIKE 'A%';
GO

-- use CTEs to get distinct values
WITH cte AS
(
	SELECT	DISTINCT FirstName
	FROM	AdventureWorks2017.Person.Person
)
SELECT	STRING_AGG(FirstName, ',') NamesList
FROM	cte
WHERE	FirstName LIKE 'Z%';
GO

-- show difference between CONCAT_WS and STRING_AGG
-- the first one concatenates literal values and/or values from different columns of the SAME ROW
-- the second one concatenates values from different rows
SELECT
	CONCAT_WS(',', Title, FirstName, MiddleName, LastName) AS FullName
,	STRING_AGG(E1.EmailAddress, ';') AS EMails
FROM	AdventureWorks2017.Person.Person AS P1
JOIN	AdventureWorks2017.Person.EmailAddress AS E1
  ON	P1.BusinessEntityID = E1.BusinessEntityID
GROUP BY
	P1.Title, P1.FirstName, P1.MiddleName, P1.LastName
HAVING
	COUNT(*) > 1;
GO

-- note that for Amy,Rusko the email adresses are not in order
-- amy7@adventure-works.com;amy4@adventure-works.com;amy3@adventure-works.com
SELECT
	CONCAT_WS(',', Title, FirstName, MiddleName, LastName) AS FullName
,	STRING_AGG(E1.EmailAddress, ';')
		WITHIN GROUP (ORDER BY E1.EmailAddress ASC) AS EMails
FROM	AdventureWorks2017.Person.Person AS P1
JOIN	AdventureWorks2017.Person.EmailAddress AS E1
  ON	P1.BusinessEntityID = E1.BusinessEntityID
GROUP BY
	P1.Title, P1.FirstName, P1.MiddleName, P1.LastName
HAVING
	COUNT(*) > 1;
GO

-- think of it also for ninja scripting :-)
SELECT
	T1.[name] AS table_name
,	STRING_AGG(CONCAT('[', C1.[name], ']'), ',')
		WITHIN GROUP (ORDER BY C1.column_id) AS column_list
FROM	AdventureWorks2017.sys.tables AS T1
JOIN	AdventureWorks2017.sys.columns AS C1
  ON	T1.[object_id] = C1.[object_id]
GROUP BY
	T1.[name];
GO

-- e.g. get insert/select from statements with column enumeration and no identity
SELECT
	CONCAT(
		'INSERT '
		, '[', S1.[name], '].[', T1.[name], ']'
		, ' (', (STRING_AGG(CONCAT('[', C1.[name], ']'), ',') WITHIN GROUP (ORDER BY C1.column_id)), ')'
		, ' SELECT'
		, (STRING_AGG(CONCAT('[', C1.[name], ']'), ',') WITHIN GROUP (ORDER BY C1.column_id))
		, ' FROM [tmp].[', T1.[name], '];'
		) AS SQLStmt
FROM	AdventureWorks2017.sys.tables AS T1
JOIN	AdventureWorks2017.sys.columns AS C1
  ON	T1.[object_id] = C1.[object_id]
JOIN	AdventureWorks2017.sys.schemas AS S1
  ON	T1.[schema_id] = S1.[schema_id]
GROUP BY
	S1.[name], T1.[name];
GO
