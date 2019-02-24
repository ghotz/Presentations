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
-- Credits:		SQL Server Tiger Team 
------------------------------------------------------------------------

USE AdventureWorks2012;
GO

------------------------------------------------------------------------
-- Protected breaking changes: parsing dates
------------------------------------------------------------------------
-- Note: the latest version supporting 90 is SQL Server 2012
ALTER DATABASE AdventureWorks2012 SET COMPATIBILITY_LEVEL = 90;
GO

-- This worked in SQL Server 2005 and change is protected
SELECT	DATEPART(year, '2007/05-30');
GO

-- Stops working when you upgrade to a new compatibility level
ALTER DATABASE AdventureWorks2012 SET COMPATIBILITY_LEVEL = 100;
GO
-- Returns error 241 "Conversion failed when converting date and/or time from character string."
SELECT	DATEPART(year, '2007/05-30');
GO

-- Application needs to be changed
SELECT	DATEPART(year, '2007/05/30');
SELECT	DATEPART(year, '2007-05-30');
GO

------------------------------------------------------------------------
-- Protected breaking changes: improved accuracy
------------------------------------------------------------------------
USE AdventureWorks2012;
GO

ALTER DATABASE AdventureWorks2012 SET COMPATIBILITY_LEVEL = 120;
GO
DECLARE @value datetime = '1900-01-01 00:00:00.003';
SELECT CAST(@value AS datetime2);
GO
ALTER DATABASE AdventureWorks2012 SET COMPATIBILITY_LEVEL = 130;
GO
DECLARE @value datetime = '1900-01-01 00:00:00.003';
SELECT CAST(@value AS datetime2);
GO

-- Warning! Since in this case we're not referencing a particular
-- database, the compatibility level is inferred from the default
-- for the connection which is AdventureWorks2012.

-- Verify that switching back to master will use its compatibility level
ALTER DATABASE AdventureWorks2012 SET COMPATIBILITY_LEVEL = 120;
GO
USE master;
GO
DECLARE @value datetime = '1900-01-01 00:00:00.003';
SELECT CAST(@value AS datetime2);
GO
SELECT CAST(CAST('1900-01-01 00:00:00.003' as datetime) AS datetime2), *
FROM AdventureWorks2012.Sales.SalesOrderDetail;
GO

-- result for compatibility <=120 is 1900-01-01 00:00:00.0030000
-- result for compatibility >=130 is 1900-01-01 00:00:00.0033333

------------------------------------------------------------------------
-- Protected breaking changes: results with LANGUAGE
------------------------------------------------------------------------
ALTER DATABASE AdventureWorks2012 SET COMPATIBILITY_LEVEL = 110;
GO
SET DATEFORMAT dmy;
DECLARE @t2 date = '12/5/2011';
SET LANGUAGE dutch;
SELECT CONVERT(varchar(11), @t2, 106);
SET LANGUAGE english;
GO
ALTER DATABASE AdventureWorks2012 SET COMPATIBILITY_LEVEL = 120;
GO
SET DATEFORMAT dmy;
DECLARE @t2 date = '12/5/2011';
SET LANGUAGE dutch;
SELECT CONVERT(varchar(11), @t2, 106);
SET LANGUAGE english;
GO

-- result for compatibility <=110 is 12 May 2011
-- result for compatibility >=120 is 12 mei 2011

------------------------------------------------------------------------
-- Unprotected breaking changes: system objects
------------------------------------------------------------------------
-- No matter what database compatiblity level is used, beginning from
-- SQL Server version 2012 (11.x) this query fails with error 207
-- "Invalid column name 'single_pages_kb'"
ALTER DATABASE AdventureWorks2012 SET COMPATIBILITY_LEVEL = 100;
GO
SELECT single_pages_kb FROM sys.dm_os_memory_clerks;
GO

-- Column was simply renamed, documented in
-- https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-memory-clerks-transact-sql
-- note that we don't need to change compatiblity
SELECT pages_kb FROM sys.dm_os_memory_clerks;
GO

-- Still... breaks scripts and forces handling multiple scenarios
-- in environments with multiple versions deployed (most scenarios)

------------------------------------------------------------------------
-- Discontinued functionalities: FASTFIRSTROW
------------------------------------------------------------------------
-- FASTFIRSTROW option was removed in SQL Server 2012 no matter what
-- compatibility level you choose, it will return error 321
-- ""FASTFIRSTROW" is not a recognized table hints option [...]"
ALTER DATABASE AdventureWorks2012 SET COMPATIBILITY_LEVEL = 100;
GO
SELECT	*
FROM	AdventureWorks2012.HumanResources.Employee WITH (FASTFIRSTROW);
GO
-- We need to use the new query-level OPTION parameter
-- note, again, that we don't need to change compatiblity
SELECT	*
FROM	AdventureWorks2012.HumanResources.Employee
OPTION	(FAST 1);
GO

------------------------------------------------------------------------
-- Discontinued functionalities: sp_dboption
------------------------------------------------------------------------
-- dboption was removed in SQL Server 2012, regardelss of the
-- compatiblity level, executing it will return error 2812
-- "Could not find stored procedure 'sp_dboption'"
EXEC sp_dboption 'AdventureWorks2012', 'autoshrink', 'false';
GO
-- We need to use the new ALTER DATABASE command
ALTER DATABASE AdventureWorks2012 SET AUTO_SHRINK OFF WITH NO_WAIT;
GO
