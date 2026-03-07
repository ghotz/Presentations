USE AdventureWorks2012;
GO

--
-- Using ROWCOUNT to restrict the number of rows to be
-- deleted/inserted/updated is deprecated in SQL Server 2016
--
IF OBJECT_ID('dbo.TestMA1') IS NOT NULL
	DROP PROCEDURE dbo.TestMA1;
GO

CREATE PROCEDURE dbo.TestMA1
AS
	SET ROWCOUNT 500;
	DELETE	Sales.SalesOrderHeader;
	SET ROWCOUNT 0;
GO

IF OBJECT_ID('dbo.TestMA2') IS NOT NULL
	DROP PROCEDURE dbo.TestMA2;
GO

CREATE PROCEDURE dbo.TestMA2
AS
	--	Thid sys procedure is deprecated in SQL 2016
	DBCC DBREINDEX('Sales.SalesOrderHeader');
GO
