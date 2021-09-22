------------------------------------------------------------------------
-- Copyright:   2019 Gianluca Hotz
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
-- Credits:    
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Create Linked Server
------------------------------------------------------------------------
-- Show how to create it with SSMS
-- Note: User LinkedServerUser needs exist on target system
USE [master]
GO
EXEC master.dbo.sp_addlinkedserver @server = N'SQLUX', @srvproduct=N'SQL Server';
EXEC master.dbo.sp_serveroption @server=N'SQLUX', @optname=N'rpc', @optvalue=N'true'
EXEC master.dbo.sp_serveroption @server=N'SQLUX', @optname=N'rpc out', @optvalue=N'true'
EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname = N'SQLUX', @locallogin = NULL , @useself = N'False', @rmtuser = N'LinkedServerUser', @rmtpassword = N'Passw0rd!'
GO

------------------------------------------------------------------------
-- Linked Server Metadata
------------------------------------------------------------------------
SELECT * FROM sys.servers;
SELECT * FROM sys.linked_logins;
GO

------------------------------------------------------------------------
-- Explore Remote Metadata
------------------------------------------------------------------------
EXEC sys.sp_catalogs @server_name = N'SQLUX';
GO
EXEC sys.sp_tables_ex
	@table_server = N'SQLUX'
,	@table_catalog = N'AdventureWorks'
,	@table_schema = N'Sales';
GO
EXEC sys.sp_columns_ex
	@table_server = N'SQLUX'
,	@table_catalog = N'AdventureWorks'
,	@table_schema = N'Sales'
,	@table_name = N'SalesOrderHeader';
GO

------------------------------------------------------------------------
-- Remote Data Access predicate pushdown
------------------------------------------------------------------------
-- execute including Actual Execution Plan and always check estimates
SELECT	SalesOrderID, OrderDate, CustomerID
FROM	SQLUX.AdventureWorks.Sales.SalesOrderHeader
WHERE	OrderDate = '2004-05-01';
GO
-- query predicate is pushed to remote system:
-- 1) an index on the remote table can be used
-- 2) in any case, only filtered rows are returned

-- let's try with a slightly different predicate
SELECT	SalesOrderID, OrderDate, CustomerID
FROM	SQLUX.AdventureWorks.Sales.SalesOrderHeader
WHERE	YEAR(OrderDate) = 2004;
GO
-- the predicate can't be pushed to the target system so
-- now all 31k rows are returned and filtered locally

-- in some cases we may be able to rewrite the query
SELECT	SalesOrderID, OrderDate, CustomerID
FROM	SQLUX.AdventureWorks.Sales.SalesOrderHeader
WHERE	OrderDate >= '2004-01-01' AND OrderDate < '2005-01-01';
GO
-- but it's not always possibile and we may need to submit
-- the whole query, or part of it, with a different method
-- please note estimates are fixed in this case (10k rows)
SELECT	*
FROM	OPENQUERY(SQLUX, 
		N'SELECT SalesOrderID, OrderDate, CustomerID
		FROM AdventureWorks.Sales.SalesOrderHeader
		WHERE	YEAR(OrderDate) = 2004;'
		);
GO
-- or better to avoid dynamic sql problems/injection
-- still fiex estimate
EXEC SQLUX.AdventureWorks.sys.sp_executesql
	@stmt = N'SELECT SalesOrderID, OrderDate, CustomerID
	FROM Sales.SalesOrderHeader WHERE YEAR(OrderDate) = @p1'
,	@params = N'@p1 int'
,	@p1 = 2004;
GO
-- however rowset binding is not the same between SELECT and EXEC
-- so this may not be possibile without additional changes or
-- using a (temporary) table to hold intermediate results

------------------------------------------------------------------------
-- Remote Data Access metadata changes
------------------------------------------------------------------------
DROP TABLE IF EXISTS #tmp;
CREATE TABLE #tmp (
	ContactTypeID	int				NOT NULL
,	ContactName		nvarchar(50)	NOT NULL
,	ModifiedDate	datetime		NOT NULL
);
GO

INSERT	#tmp
SELECT	*
FROM	SQLUX.AdventureWorks.Person.ContactType;
GO

-- now, someone changes the original schema adding a new column
EXEC SQLUX.AdventureWorks.sys.sp_executesql
	@stmt = N'ALTER TABLE Person.ContactType ADD ModifiedUser sysname';
GO

-- the query now fails
INSERT	#tmp
SELECT	*
FROM	SQLUX.AdventureWorks.Person.ContactType;
GO

-- of course the root of the problems is using * stil...

------------------------------------------------------------------------
-- Cleanup
------------------------------------------------------------------------
EXEC SQLUX.AdventureWorks.sys.sp_executesql
	@stmt = N'ALTER TABLE Person.ContactType DROP COLUMN ModifiedUser';
GO
EXEC master.dbo.sp_dropserver @server=N'SQLUX', @droplogins='droplogins';
GO
