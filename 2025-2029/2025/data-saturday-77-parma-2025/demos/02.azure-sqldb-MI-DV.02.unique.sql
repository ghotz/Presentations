------------------------------------------------------------------------
-- Copyright:   2025 Gianluca Hotz
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
--              The above copyright notice and this permission notice
--              shall be included in all copies or substantial portions
--              of the Software.
--              THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
--              ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
--              LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
--              FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
--              EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
--              FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
--              AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--              OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
--              OTHER DEALINGS IN THE SOFTWARE.
-- Credits:     https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/data-virtualization-overview 
--              https://learn.microsoft.com/en-us/training/modules/sql-server-2022-data-virtualization
------------------------------------------------------------------------

USE polybase;
GO

------------------------------------------------------------------------
------------------------------------------------------------------------
-- Statistics with OPENROWSET
------------------------------------------------------------------------
-----------------------------------------------------------------------

------------------------------------------------------------------------
-- Covid Dataset
------------------------------------------------------------------------
-- show estimated plan out of filter (~312.753 rows)
SELECT	COUNT(*)
FROM	OPENROWSET
(
    BULK 'bing_covid-19_data.parquet'
,	FORMAT = 'parquet'
,   DATA_SOURCE = 'Public_Covid'
) AS filerows
WHERE [updated] BETWEEN '2021-01-01' AND '2021-03-01';
GO

-- create statistics, only single column
EXEC sys.sp_create_openrowset_statistics N'
SELECT	[updated]
FROM	OPENROWSET
(
    BULK ''bing_covid-19_data.parquet''
,	FORMAT = ''parquet''
,   DATA_SOURCE = ''Public_Covid''
) AS filerows
';
GO

-- show estimated plan out of filter (~295.472 rows)
SELECT	COUNT(*)
FROM	OPENROWSET
(
    BULK 'bing_covid-19_data.parquet'
,	FORMAT = 'parquet'
,   DATA_SOURCE = 'Public_Covid'
) AS filerows
WHERE [updated] BETWEEN '2021-01-01' AND '2021-03-01';
GO

-- to update the statistics, drop them and re-create them
EXEC sys.sp_drop_openrowset_statistics N'
SELECT	[updated]
FROM	OPENROWSET
(
    BULK ''bing_covid-19_data.parquet''
,	FORMAT = ''parquet''
,   DATA_SOURCE = ''Public_Covid''
) AS filerows
';
GO

------------------------------------------------------------------------
-- NYC Taxi Dataset
------------------------------------------------------------------------
-- show estimated plan out of filter
SELECT COUNT(*)
FROM OPENROWSET(
    BULK 'yellow/puYear=*/puMonth=*/*.parquet'
,   DATA_SOURCE = 'NYCTaxiExternalDataSource'  
,   FORMAT = 'parquet'
) AS filerows
WHERE [tpepPickupDateTime] BETWEEN '2021-01-01' AND '2021-03-01';
GO

-- create statistics, only single column
EXEC sys.sp_create_openrowset_statistics N'
SELECT	[tpepPickupDateTime]
FROM	OPENROWSET
(
	BULK ''yellow/puYear=*/puMonth=*/*.parquet''
,   DATA_SOURCE = ''NYCTaxiExternalDataSource''
,	FORMAT = ''parquet''
) AS filerows
';
GO
-- show estimated plan out of filter
SELECT COUNT(*)
FROM OPENROWSET(
    BULK 'yellow/puYear=*/puMonth=*/*.parquet'
,   DATA_SOURCE = 'NYCTaxiExternalDataSource'  
,   FORMAT = 'parquet'
) AS filerows
WHERE [tpepPickupDateTime] BETWEEN '2021-01-01' AND '2021-03-01';
GO
-- to update the statistics, drop them and re-create them
EXEC sys.sp_drop_openrowset_statistics N'
SELECT	[tpepPickupDateTime]
FROM	OPENROWSET
(
	BULK ''yellow/puYear=*/puMonth=*/*.parquet''
,   DATA_SOURCE = ''NYCTaxiExternalDataSource''
,	FORMAT = ''parquet''
) AS filerows
';
GO
------------------------------------------------------------------------
------------------------------------------------------------------------
-- Statistics on an external table
------------------------------------------------------------------------
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Covid Dataset
------------------------------------------------------------------------
-- show estimated plan out of filter (~316.211 rows)
SELECT COUNT(*) FROM ext_covid_data WHERE [updated] BETWEEN '2021-01-01' AND '2021-03-01';
GO
-- create statistics
--DROP STATISTICS ext_covid_data.Stats_ext_covid_data_updated;
CREATE STATISTICS Stats_ext_covid_data_updated ON ext_covid_data([updated]) WITH FULLSCAN;
GO

-- show estimated plan out of filter (~295.463 rows)
SELECT COUNT(*) FROM ext_covid_data WHERE [updated] BETWEEN '2021-01-01' AND '2021-03-01';
GO

------------------------------------------------------------------------
-- NYC Taxi Dataset
------------------------------------------------------------------------
-- show estimated plan out of filter (~17 rows)
SELECT COUNT(*) FROM tbl_TaxiRides WHERE [tpepPickupDateTime] BETWEEN '2021-01-01' AND '2021-03-01';
GO

-- create statistics
--DROP STATISTICS tbl_TaxiRides.Stats_tbl_TaxiRides_tpepPickupDateTime;
CREATE STATISTICS Stats_tbl_TaxiRides_tpepPickupDateTime ON tbl_TaxiRides([tpepPickupDateTime]) WITH FULLSCAN;
GO

-- show estimated plan out of filter
SELECT COUNT(*) FROM tbl_TaxiRides WHERE [tpepPickupDateTime] BETWEEN '2021-01-01' AND '2021-03-01';
GO

------------------------------------------------------------------------
------------------------------------------------------------------------
-- CREATE EXTERNAL TABLE AS SELECT (CETAS)
------------------------------------------------------------------------
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Configure feature at instance level, on Managed Instance need to be
-- configured with PowerShell with:
-- Set-AzSqlServerConfigurationOption
--  -ResourceGroupName "resource_group_name"
--  -InstanceName "ManagedInstanceName"
--  -Name "allowPolybaseExport"
--  -Value 1
------------------------------------------------------------------------
EXEC sp_configure N'allow polybase export', 1;
RECONFIGURE WITH OVERRIDE;
GO

------------------------------------------------------------------------
-- Create Database Scoped Credential for blob storage
------------------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.database_scoped_credentials WHERE name = N'blob_storage')
    DROP DATABASE SCOPED CREDENTIAL blob_storage;
GO
CREATE DATABASE SCOPED CREDENTIAL blob_storage
    WITH IDENTITY = 'SHARED ACCESS SIGNATURE',
    SECRET = '?sv=2020-02-10&spr=https&st=2025-11-29T01%3A02%3A43Z&se=2025-12-30T01%3A02%3A00Z&sr=c&sp=racwdlmeop&sig=AXAsbvM1P38HCONov2POHxQgLXAKbrqGUnVY3QTXg1o%3D';
GO

------------------------------------------------------------------------
-- Create the data source
------------------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.external_data_sources WHERE name = N'AdvDataSource')
DROP EXTERNAL DATA SOURCE AdvDataSource;
GO

CREATE EXTERNAL DATA SOURCE AdvDataSource
WITH (
    LOCATION = 'abs://ugissdemo.blob.core.windows.net/demo',
    CREDENTIAL = blob_storage
);
GO
------------------------------------------------------------------------
-- Create External Data Format
------------------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.external_file_formats WHERE name = N'AdvParquetFormat')
      DROP EXTERNAL FILE FORMAT AdvParquetFormat;
GO
CREATE EXTERNAL FILE FORMAT AdvParquetFormat
    WITH(
        FORMAT_TYPE = PARQUET
    );
GO

------------------------------------------------------------------------
-- Check records by year
------------------------------------------------------------------------
SELECT COUNT(*) AS QTY, DATEPART(YYYY, [DueDate]) AS [YEAR]
FROM  [AdventureWorks2025].[Purchasing].[PurchaseOrderDetail]
GROUP BY DATEPART(YYYY, [DueDate])
ORDER BY [YEAR];
GO

------------------------------------------------------------------------
-- Create a one-time export of certain years
------------------------------------------------------------------------
IF OBJECT_ID(N'ex_data_2022_2023', N'ET') IS NOT NULL
      DROP EXTERNAL TABLE ex_data_2022_2023;
GO

CREATE EXTERNAL TABLE ex_data_2022_2023
WITH(
        LOCATION = 'data_2022_2023',
        DATA_SOURCE = AdvDataSource,
        FILE_FORMAT = AdvParquetFormat
)AS
SELECT  *
FROM    [AdventureWorks2025].[Purchasing].[PurchaseOrderDetail] 
WHERE   YEAR([DUEDATE]) < 2024;
GO
-- show directory/file in Azure Storage Explorer
-- show data in SSMS

------------------------------------------------------------------------
------------------------------------------------------------------------
-- Use CETAS to archive old data
------------------------------------------------------------------------
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Make a copy of the table to leave demo database intact
------------------------------------------------------------------------
DROP TABLE IF EXISTS [AdventureWorks2025].[Purchasing].[PurchaseOrderDetail2];
GO
SELECT  *
INTO    [AdventureWorks2025].[Purchasing].[PurchaseOrderDetail2]
FROM    [AdventureWorks2025].[Purchasing].[PurchaseOrderDetail];
GO

------------------------------------------------------------------------
-- Export the data using CETAS
------------------------------------------------------------------------
IF OBJECT_ID(N'ex_data_2022', N'ET') IS NOT NULL
      DROP EXTERNAL TABLE ex_data_2022;
GO
CREATE EXTERNAL TABLE ex_data_2022
WITH(
        LOCATION = 'archive/data_2022',
        DATA_SOURCE = AdvDataSource,
        FILE_FORMAT = AdvParquetFormat
)AS
SELECT  *
FROM    [AdventureWorks2025].[Purchasing].[PurchaseOrderDetail2] 
WHERE   YEAR([DUEDATE]) = 2022;
GO
IF OBJECT_ID(N'ex_data_2023', N'ET') IS NOT NULL
      DROP EXTERNAL TABLE ex_data_2023;
GO
CREATE EXTERNAL TABLE ex_data_2023
WITH(
        LOCATION = 'archive/data_2023',
        DATA_SOURCE = AdvDataSource,
        FILE_FORMAT = AdvParquetFormat
)AS
SELECT  *
FROM    [AdventureWorks2025].[Purchasing].[PurchaseOrderDetail2] 
WHERE   YEAR([DUEDATE]) = 2024;
GO
IF OBJECT_ID(N'ex_data_2024', N'ET') IS NOT NULL
      DROP EXTERNAL TABLE ex_data_2024;
GO
CREATE EXTERNAL TABLE ex_data_2024
WITH(
        LOCATION = 'archive/data_2024',
        DATA_SOURCE = AdvDataSource,
        FILE_FORMAT = AdvParquetFormat
)AS
SELECT  *
FROM    [AdventureWorks2025].[Purchasing].[PurchaseOrderDetail2] 
WHERE   YEAR([DUEDATE]) = 2024;
GO

------------------------------------------------------------------------
-- Delete old data
------------------------------------------------------------------------
DELETE  [AdventureWorks2025].[Purchasing].[PurchaseOrderDetail2]
WHERE   YEAR([DUEDATE]) < 2025;
GO

------------------------------------------------------------------------
-- Create a view to union the data
------------------------------------------------------------------------
CREATE OR ALTER VIEW vwPurchaseOrderDetail2
AS
SELECT * FROM ex_data_2022
UNION ALL
SELECT * FROM ex_data_2023
UNION ALL
SELECT * FROM ex_data_2024
UNION ALL
SELECT * FROM [AdventureWorks2025].[Purchasing].[PurchaseOrderDetail2];
GO

------------------------------------------------------------------------
-- Check records by year trough view (show execution plan)
------------------------------------------------------------------------
SELECT  COUNT(*) AS QTY, DATEPART(YYYY, [DueDate]) AS [YEAR]
FROM    vwPurchaseOrderDetail2
WHERE   DATEPART(YYYY, [DueDate]) IN (2024, 2025)
GROUP BY DATEPART(YYYY, [DueDate])
ORDER BY [YEAR];
GO

------------------------------------------------------------------------
-- Note that all years are scanned before being filtered
-- To avoid it, we can exploit early binding contradiction detection
-- that prune execution plan subtress accordingly
-- Thanks to Diego(?) for pointing out to show it!
------------------------------------------------------------------------
CREATE OR ALTER VIEW vwPurchaseOrderDetail2
AS
SELECT * FROM ex_data_2022 WHERE DATEPART(YYYY, [DueDate]) = 2022
UNION ALL
SELECT * FROM ex_data_2023 WHERE DATEPART(YYYY, [DueDate]) = 2023
UNION ALL
SELECT * FROM ex_data_2024 WHERE DATEPART(YYYY, [DueDate]) = 2024
UNION ALL
SELECT * FROM [AdventureWorks2025].[Purchasing].[PurchaseOrderDetail2]
WHERE DATEPART(YYYY, [DueDate]) = 2025;
GO

-- re-run the query and check that 2022 and 2023 subtrees are gone
SELECT  COUNT(*) AS QTY, DATEPART(YYYY, [DueDate]) AS [YEAR]
FROM    vwPurchaseOrderDetail2
WHERE   DATEPART(YYYY, [DueDate]) IN (2024, 2025)
GROUP BY DATEPART(YYYY, [DueDate])
ORDER BY [YEAR];
GO

------------------------------------------------------------------------
------------------------------------------------------------------------
-- Use CETAS to export data with partitioning (only Managed Instance!)
------------------------------------------------------------------------
------------------------------------------------------------------------
IF OBJECT_ID(N'SalesOrdersExternalPartitioned', N'ET') IS NOT NULL
      DROP EXTERNAL TABLE SalesOrdersExternalPartitioned;
GO
CREATE EXTERNAL TABLE SalesOrdersExternalPartitioned
WITH
(
    LOCATION = 'PartitionedOrders/year=*/month=*/'
,   DATA_SOURCE = AdvDataSource
,   FILE_FORMAT = AdvParquetFormat
    -- year and month will correspond to the two respective wildcards in folder path    
,   PARTITION 
    (
        [Year]
    ,   [Month]
    ) 
)
AS
SELECT
    *
,   YEAR(OrderDate) AS [Year]
,   MONTH(OrderDate) AS [Month]
FROM [AdventureWorks2025].[Sales].[SalesOrderHeader]
WHERE
    OrderDate < '2025-01-01';
GO

-- you can query the newly created partitioned external table
SELECT COUNT (*) FROM SalesOrdersExternalPartitioned;
GO

