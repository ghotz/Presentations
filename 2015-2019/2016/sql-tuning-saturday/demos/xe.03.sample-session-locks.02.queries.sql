------------------------------------------------------------------------
--	Script:			xe.04.sample-session-locks-queries.sql
--	Description:	Query di esempio per sessione lock
--	Author:			Gianluca Hotz (SolidQ)
--	Copyright:		Attribution-NonCommercial-ShareAlike 3.0
------------------------------------------------------------------------
SELECT COUNT(*) FROM [AdventureWorks2012].[Sales].[SalesOrderDetail] WITH (UPDLOCK);
GO

SELECT COUNT(*) FROM [AdventureWorksLT2012].[SalesLT].[SalesOrderDetail] WITH (UPDLOCK);
GO
