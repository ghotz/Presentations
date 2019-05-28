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
-- Setup other connections
------------------------------------------------------------------------

-- execute this on connection 1
USE AdventureWorks2012;
GO
BEGIN TRANSACTION;
	UPDATE	Person.PersonPhone
	SET		PhoneNumber = '999-999-9999'
	WHERE	BusinessEntityID = 1;
-- ROLLBACK TRANSACTION
GO

-- execute this on connection 2
USE AdventureWorks2012;
GO
BEGIN TRANSACTION;
	UPDATE	Person.PersonPhone
	SET		PhoneNumber = '999-999-9999'
	WHERE	BusinessEntityID = 2;
	SELECT	*
	FROM	Person.PersonPhone
	WHERE	BusinessEntityID = 1;
-- ROLLBACK TRANSACTION
GO

-- execute this on connection 3
USE AdventureWorks2012;
GO
BEGIN TRANSACTION;
	SELECT	*
	FROM	Person.PersonPhone
	WHERE	BusinessEntityID = 2;
-- ROLLBACK TRANSACTION
GO

------------------------------------------------------------------------
-- Show Usage
------------------------------------------------------------------------

-- Default
EXEC sp_whoisactive;
GO

-- Get sleping tasks
EXEC sp_whoisactive @show_sleeping_spids = 2;
GO

-- Get lock details
EXEC sp_whoisactive @find_block_leaders = 1, @get_locks = 1;
GO

------------------------------------------------------------------------
-- Close locking connections, run next query in a separate connection
------------------------------------------------------------------------
DROP TABLE IF EXISTS #tmp;

SELECT	
	p.Name AS ProductName,((OrderQty * UnitPrice) * (1.0 - UnitPriceDiscount)) AS Price
INTO	#tmp
FROM AdventureWorks2012.Production.Product AS p 
INNER JOIN AdventureWorks2012.Sales.SalesOrderDetail AS sod
ON p.ProductID = sod.ProductID 
ORDER BY ProductName ASC;
GO 1000
GO

-- Get detailed task info
EXEC sp_whoisactive @get_task_info = 2;
GO

-- Get detailed task info and plans
EXEC sp_whoisactive @get_task_info = 2, @get_plans = 1;
GO

-- Get help
EXEC sp_whoisactive @help = 1;
GO

-- Generate table schema for colletion
DECLARE	@schema varchar(max);
EXEC sp_whoisactive @return_schema = 1, @schema = @schema OUTPUT;
SELECT	@schema;
GO

 --DROP TABLE IF EXISTS tempdb.dbo.test1;
 --CREATE TABLE tempdb.dbo.test1 ( [dd hh:mm:ss.mss] varchar(8000) NULL,[session_id] smallint NOT NULL,[sql_text] xml NULL,[login_name] nvarchar(128) NOT NULL,[wait_info] nvarchar(4000) NULL,[CPU] varchar(30) NULL,[tempdb_allocations] varchar(30) NULL,[tempdb_current] varchar(30) NULL,[blocking_session_id] smallint NULL,[reads] varchar(30) NULL,[writes] varchar(30) NULL,[physical_reads] varchar(30) NULL,[used_memory] varchar(30) NULL,[status] varchar(30) NOT NULL,[open_tran_count] varchar(30) NULL,[percent_complete] varchar(30) NULL,[host_name] nvarchar(128) NULL,[database_name] nvarchar(128) NULL,[program_name] nvarchar(128) NULL,[start_time] datetime NOT NULL,[login_time] datetime NULL,[request_id] int NULL,[collection_time] datetime NOT NULL);
EXEC sp_whoisactive @destination_table = 'tempdb.dbo.test1';
GO

SELECT	*
FROM	tempdb.dbo.test1;
GO

