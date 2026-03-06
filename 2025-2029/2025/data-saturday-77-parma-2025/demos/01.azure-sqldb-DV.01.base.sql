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
-- Credits:     https://learn.microsoft.com/en-us/azure/azure-sql/database/data-virtualization-overview
--              https://learn.microsoft.com/en-us/training/modules/sql-server-2022-data-virtualization
------------------------------------------------------------------------

------------------------------------------------------------------------
------------------------------------------------------------------------
-- Getting started with a publicly available storage account 
--
-- Datase Docs: https://learn.microsoft.com/en-us/azure/open-datasets/dataset-bing-covid-19
------------------------------------------------------------------------
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Simple query
--
------------------------------------------------------------------------
-- Show Execution Plan with Live Query Statistics
SELECT  TOP 10 *
FROM    OPENROWSET
(
    BULK 'abs://public@pandemicdatalake.blob.core.windows.net/curated/covid-19/bing_covid-19_data/latest/bing_covid-19_data.parquet'
,   FORMAT = 'parquet'
) AS filerows;
GO

------------------------------------------------------------------------
-- Please note we accessing anonymously otherwise we would need to
-- create a database master key and a credential to be used to connect
-- to the target storage system
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Create the database master key
------------------------------------------------------------------------
DECLARE @randomWord VARCHAR(64) = NEWID();
DECLARE @createMasterKey NVARCHAR(500) = N'
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = ''##MS_DatabaseMasterKey##'')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = '  + QUOTENAME(@randomWord, '''')
EXECUTE sp_executesql @createMasterKey;
GO
SELECT * FROM sys.symmetric_keys;
GO

------------------------------------------------------------------------
-- Create the database scoped credential
------------------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.database_scoped_credentials WHERE name = N'PublicCredential')
    DROP DATABASE SCOPED CREDENTIAL PublicCredential;
GO

CREATE DATABASE SCOPED CREDENTIAL PublicCredential
WITH IDENTITY = 'SHARED ACCESS SIGNATURE',
SECRET = '<KEY>'; -- This example doesn't need the SECRET because the data source is public
GO

------------------------------------------------------------------------
-- Create the data source (format is PARQUET)
------------------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.external_data_sources WHERE name = N'Public_Covid')
DROP EXTERNAL DATA SOURCE Public_Covid;
GO

CREATE EXTERNAL DATA SOURCE Public_Covid
WITH (
    LOCATION = 'abs://pandemicdatalake.blob.core.windows.net/public/curated/covid-19/bing_covid-19_data/latest',
    CREDENTIAL = [PublicCredential]
);
GO

------------------------------------------------------------------------
-- Query the data again with data source
------------------------------------------------------------------------
-- Show Execution Plan with Live Query Statistics
SELECT  TOP 10 *
FROM    OPENROWSET
(
    BULK 'bing_covid-19_data.parquet'
,   FORMAT = 'parquet'
,   DATA_SOURCE = 'Public_Covid'
) AS filerows;
GO

-- Takes around 1 minute on a General Purpose 1-6 vcores serverless...
SELECT 
    filerows.admin_region_1
,   SUM(CAST(filerows.confirmed AS BIGINT)) AS Confirmed
FROM OPENROWSET
(
    BULK 'bing_covid-19_data.parquet'
,   FORMAT = 'parquet'
,   DATA_SOURCE = 'Public_Covid'
) AS filerows
WHERE
    filerows.country_region = 'United States'
AND filerows.admin_region_1  IS NOT NULL
GROUP BY filerows.admin_region_1 
ORDER BY confirmed DESC;
GO

-- Takes around 1 and 28 seconds on a General Purpose 1-6 vcores serverless...
SELECT  A.CountryRegion, A.StateProvince
,       SUM(CAST(filerows.confirmed AS BIGINT)) AS Confirmed
,       COUNT(DISTINCT C.CustomerID) AS NumberOfCustomers
FROM OPENROWSET 
     (BULK 'bing_covid-19_data.parquet'
     , FORMAT = 'PARQUET'
     , DATA_SOURCE = 'Public_Covid')
     AS filerows
JOIN    [SalesLT].[Address] AS A
  ON    A.StateProvince = filerows.admin_region_1
 AND    A.CountryRegion = filerows.country_region
JOIN    [SalesLT].[CustomerAddress] AS C
  ON    A.AddressID = C.AddressID
GROUP BY
         A.CountryRegion, A.StateProvince
ORDER BY
         A.CountryRegion, A.StateProvince;
GO
------------------------------------------------------------------------
------------------------------------------------------------------------
-- Schema inference
--
-- Atomatic schema inference:
--  * works only with parquet files
--  * is helpful in many situations e.g. to explore data
--  * can be problematic e.g. parquet files don't contain metadata about
--    maximum character column length, so the instance infers it as
--    varchar(8000) which can cause poor query performance
------------------------------------------------------------------------
------------------------------------------------------------------------

------------------------------------------------------------------------
-- System SP to describe result set eg. selecting a subset of rows
-- note the varchar(8000) inference for country_region & admin_region_1
------------------------------------------------------------------------
EXEC sp_describe_first_result_set N'
    SELECT
        TOP 10 id, confirmed, country_region, admin_region_1
    FROM
        OPENROWSET
    (
        BULK ''bing_covid-19_data.parquet''
    ,   FORMAT = ''parquet''
    ,   DATA_SOURCE = ''Public_Covid''
    ) AS filerows 
 ';
GO

------------------------------------------------------------------------
-- Schema can be specified using WITH clause
------------------------------------------------------------------------
SELECT
    TOP 10 id, confirmed, country_region, admin_region_1
FROM
    OPENROWSET
(
    BULK 'bing_covid-19_data.parquet'
,   FORMAT = 'parquet'
,   DATA_SOURCE = 'Public_Covid'
) 
WITH (
    id              int
,   confirmed       int
,   country_region  nvarchar(50)    -- 50 instead of the inferred 8000
,   admin_region_1  nvarchar(50)    -- 50 instead of the inferred 8000
) AS filerows;
GO

------------------------------------------------------------------------
-- Schema inference does not work with CSV format
------------------------------------------------------------------------
SELECT TOP 10 id, updated, confirmed, confirmed_change
FROM
    OPENROWSET(
        BULK 'abs://public@pandemicdatalake.blob.core.windows.net/curated/covid-19/bing_covid-19_data/latest/bing_covid-19_data.csv'
    ,   FORMAT = 'CSV'
) AS filerows;
GO  
-- query returns error, schema needs to be specified
SELECT TOP 10 id, updated, confirmed, confirmed_change
FROM
    OPENROWSET(
        BULK 'abs://public@pandemicdatalake.blob.core.windows.net/curated/covid-19/bing_covid-19_data/latest/bing_covid-19_data.csv'
    ,   FORMAT = 'CSV'
) 
WITH (
    id                  int
,   updated             date
,   confirmed           int
,   confirmed_change    int
) AS filerows;
GO
-- we still get an error because first row is the header and we need to skip it
SELECT TOP 10 id, updated, confirmed, confirmed_change
FROM
    OPENROWSET(
        BULK 'abs://public@pandemicdatalake.blob.core.windows.net/curated/covid-19/bing_covid-19_data/latest/bing_covid-19_data.csv'
    ,   FORMAT = 'CSV'
    ,   FIRSTROW = 2
) 
WITH (
    id                  int
,   updated             date
,   confirmed           int
,   confirmed_change    int
) AS filerows;
GO

-- for CSV format additional properties like field/row terminator can be
-- specified but not COLUMN_ORDINAL like in other systems

------------------------------------------------------------------------
------------------------------------------------------------------------
-- External tables
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Get the schema to decide which column to import, in this case all
------------------------------------------------------------------------
EXEC sp_describe_first_result_set N'
    SELECT TOP 10 *
    FROM
        OPENROWSET
    (
        BULK ''bing_covid-19_data.parquet''
    ,   FORMAT = ''parquet''
    ,   DATA_SOURCE = ''Public_Covid''
    ) AS filerows 
 ';
GO

------------------------------------------------------------------------
-- Create the external file format
------------------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.external_file_formats WHERE name = N'CovidParquetFormat')
      DROP EXTERNAL FILE FORMAT CovidParquetFormat;
GO
CREATE EXTERNAL FILE FORMAT CovidParquetFormat
    WITH(
        FORMAT_TYPE = PARQUET
    );
GO

------------------------------------------------------------------------
-- Create the external table
------------------------------------------------------------------------
--DROP EXTERNAL TABLE IF EXISTS ext_covid_data;
IF OBJECT_ID(N'ext_covid_data', N'ET') IS NOT NULL
      DROP EXTERNAL TABLE ext_covid_data;
GO
CREATE EXTERNAL TABLE ext_covid_data
(
    id                  int,
    updated             date,
    confirmed           int,
    confirmed_change    int,
    deaths              int,
    deaths_change       smallint,
    recovered           int,
    recovered_change    int,
    latitude            float,
    longitude           float,
    iso2                varchar(2),
    iso3                varchar(3),
    country_region      varchar(50),
    admin_region_1      varchar(50),
    iso_subdivision     varchar(50),
    admin_region_2      varchar(50),
    load_time           datetime2(7)
)
WITH
(
    LOCATION = 'bing_covid-19_data.parquet'
,   FILE_FORMAT = CovidParquetFormat
,   DATA_SOURCE = Public_Covid
);

-- Data is ready to be queried
SELECT TOP 10 * FROM ext_covid_data;
GO

------------------------------------------------------------------------
------------------------------------------------------------------------
-- Querying multiple files and folders
--
-- Dataset docs: https://learn.microsoft.com/en-us/azure/open-datasets/dataset-taxi-yellow
------------------------------------------------------------------------
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Create external data source poiting to NYC Taxi dataset
------------------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.external_data_sources WHERE name = N'NYCTaxiExternalDataSource')
DROP EXTERNAL DATA SOURCE NYCTaxiExternalDataSource;
GO
CREATE EXTERNAL DATA SOURCE NYCTaxiExternalDataSource
WITH (
    LOCATION = 'abs://nyctlc@azureopendatastorage.blob.core.windows.net'
    --, CREDENTIAL = [] can be omitted as this is a public dataset not requiring authentication
);

------------------------------------------------------------------------
-- Explore database with Azure Storage Explorer connecting to
-- https://azureopendatastorage.blob.core.windows.net/nyctlc
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Query files with .parquet extension in folders matching name pattern
------------------------------------------------------------------------
SELECT TOP 10 *
FROM OPENROWSET(
    BULK 'yellow/puYear=*/puMonth=*/*.parquet'
,   DATA_SOURCE = 'NYCTaxiExternalDataSource'   -- note data source
,   FORMAT = 'parquet'
) AS filerows;
GO

------------------------------------------------------------------------
-- IMPORTANT: when querying multiple files or folders:
--  * all files accessed with the single OPENROWSET must have the same
--    structure (such as the same number of columns and data types)
--  * folders can't be traversed recursively
------------------------------------------------------------------------

------------------------------------------------------------------------
------------------------------------------------------------------------
-- File metadata functions filepath() and filename()
--
-- Note: filepath() is relative to DATA_SOURCE when specified
------------------------------------------------------------------------
------------------------------------------------------------------------

------------------------------------------------------------------------
--Query all files and project file path and file name information for each row:
------------------------------------------------------------------------
SELECT TOP 10
    filerows.filepath(1) as [Year_Folder]
,   filerows.filepath(2) as [Month_Folder]
,   filerows.filename() as [File_name]
,   filerows.filepath() as [Full_Path]
,   *
FROM OPENROWSET(
    BULK 'yellow/puYear=*/puMonth=*/*.parquet'
,   DATA_SOURCE = 'NYCTaxiExternalDataSource'
,   FORMAT = 'parquet')
AS filerows;
GO

------------------------------------------------------------------------
-- Filter on file_path()
------------------------------------------------------------------------
SELECT
    r.filepath() AS filepath
,   r.filepath(1) AS [year]
,   r.filepath(2) AS [month]
,   COUNT_BIG(*) AS [rows]
FROM OPENROWSET(
    BULK 'yellow/puYear=*/puMonth=*/*.parquet'
,   DATA_SOURCE = 'NYCTaxiExternalDataSource'
,   FORMAT = 'parquet'
) AS r
WHERE
        r.filepath(1) IN ('2017')
    AND r.filepath(2) IN ('10', '11', '12')
GROUP BY
    r.filepath()
,   r.filepath(1)
,   r.filepath(2)
ORDER BY
    filepath;
GO

-- Takes around 2 minutes and 20 seconds on a General Purpose 1-6 vcores serverless...
-- predicate pushdown seems to be broken at the moment even trying
-- different Windows/BIN collations when warning 16570 is raised
-- "Use a collation that enables string predicate pushdown and file elimination on storage layer."
-- a workaround can be to use dynamic SQL to build multiple queries with different 
-- predicates in the BULK path patterns and UNION ALL them
SELECT
    r.filepath() AS filepath
,   2017 AS [year]
,   10 AS [month]
,   COUNT_BIG(*) AS [rows]
FROM OPENROWSET(
    BULK 'yellow/puYear=2017/puMonth=10/*.parquet'
,   DATA_SOURCE = 'NYCTaxiExternalDataSource'
,   FORMAT = 'parquet'
) AS r
GROUP BY
    r.filepath()
UNION ALL
SELECT
    r.filepath() AS filepath
,   2017 AS [year]
,   11 AS [month]
,   COUNT_BIG(*) AS [rows]
FROM OPENROWSET(
    BULK 'yellow/puYear=2017/puMonth=11/*.parquet'
,   DATA_SOURCE = 'NYCTaxiExternalDataSource'
,   FORMAT = 'parquet'
) AS r
GROUP BY
    r.filepath()
UNION ALL
SELECT
    r.filepath() AS filepath
,   2017 AS [year]
,   12 AS [month]
,   COUNT_BIG(*) AS [rows]
FROM OPENROWSET(
    BULK 'yellow/puYear=2017/puMonth=12/*.parquet'
,   DATA_SOURCE = 'NYCTaxiExternalDataSource'
,   FORMAT = 'parquet'
) AS r
GROUP BY
    r.filepath()
ORDER BY filepath
GO

------------------------------------------------------------------------
-- Get the schema to decide which column to import, in this case all
------------------------------------------------------------------------
EXEC sp_describe_first_result_set N'
    SELECT
        *
    FROM
        OPENROWSET(
           BULK ''yellow/*/*/*.parquet''
        ,   DATA_SOURCE = ''NYCTaxiExternalDataSource''
        ,   FORMAT = ''parquet''
        ) AS nyc
 ';
GO

------------------------------------------------------------------------
-- Create the external file format
------------------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.external_file_formats WHERE name = N'NYCTaxiParquetFormat')
      DROP EXTERNAL FILE FORMAT NYCTaxiParquetFormat;
GO
CREATE EXTERNAL FILE FORMAT NYCTaxiParquetFormat
    WITH(
        FORMAT_TYPE = PARQUET
    );
GO

------------------------------------------------------------------------
-- Create the external table
------------------------------------------------------------------------
--DROP EXTERNAL TABLE IF EXISTS tbl_TaxiRides;
IF OBJECT_ID(N'tbl_TaxiRides', N'ET') IS NOT NULL
      DROP EXTERNAL TABLE tbl_TaxiRides;
GO
CREATE EXTERNAL TABLE tbl_TaxiRides
(
    vendorID                VARCHAR(100) COLLATE Latin1_General_BIN2
,   tpepPickupDateTime      DATETIME2
,   tpepDropoffDateTime     DATETIME2
,   passengerCount          INT
,   tripDistance            FLOAT
,   puLocationId            VARCHAR(8000)
,   doLocationId            VARCHAR(8000)
,   startLon                FLOAT
,   startLat                FLOAT
,   endLon                  FLOAT
,   endLat                  FLOAT
,   rateCodeId              SMALLINT
,   storeAndFwdFlag         VARCHAR(8000)
,   paymentType             VARCHAR(8000)
,   fareAmount              FLOAT
,   extra                   FLOAT
,   mtaTax                  FLOAT
,   improvementSurcharge    VARCHAR(8000)
,   tipAmount               FLOAT
,   tollsAmount             FLOAT
,   totalAmount             FLOAT
)
WITH (
    LOCATION = 'yellow/puYear=*/puMonth=*/*.parquet'
,   DATA_SOURCE = NYCTaxiExternalDataSource
,   FILE_FORMAT = NYCTaxiParquetFormat
);

------------------------------------------------------------------------
-- Table can be queried as usual however here directory pruning is not
-- supported
------------------------------------------------------------------------
SELECT  TOP 10 *
FROM    tbl_TaxiRides;
GO
