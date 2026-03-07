--
-- Available in SQL 2016 and Azure SQL Database
--

-- STRING_SPLIT()
DECLARE @tags NVARCHAR(400) = 'clothing,road,,touring,bike'  
  
SELECT value  
FROM STRING_SPLIT(@tags, ',')  
WHERE RTRIM(value) <> '';  

-- DROP IF EXISTS
-- AT TIME ZONE
-- COMPRESS/DECOMPRESS

--
-- Available in Azure SQL Database only (as of 2017-02-01)
--

-- STRING_AGG
SELECT	STRING_AGG(LastName, ',') AS csv 
FROM	SalesLT.Customer
WHERE	CustomerID < 100;
GO
-- TRIM
SELECT	TRIM( '     test    ') AS Result;
GO

-- Temporary Table History Retention
SELECT	[name] AS database_name, is_temporal_history_retention_enabled
FROM	sys.databases;
GO

--
-- Available in vNext only (as of 2017-02-01)
--

-- TRANSLATE 
SELECT TRANSLATE('2*[3+4]/{7-2}', '[]{}', '()()');
GO

-- BULK INSERT Azure Blobs ?

