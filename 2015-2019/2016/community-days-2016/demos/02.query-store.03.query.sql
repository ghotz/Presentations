------------------------------------------------------------------------
--	Description:	Query store demo query
------------------------------------------------------------------------
-- Credits: Sergio Govoni (Data Platform MVP)
-- Original article: https://blogs.msdn.microsoft.com/mvpawardprogram/2016/03/29/sql-server-2016-query-store
-- Original script: https://docs.com/sergio-govoni/6280/10-setup-querystore-database?c=ssuSrS
------------------------------------------------------------------------
USE [QueryStore];
GO

SET NOCOUNT ON;
GO

DECLARE	@sqlstmt nvarchar(max);
DECLARE	@par1 int;
DECLARE @par2 int;
DECLARE	@iterations int = 1000;

SET @sqlstmt = N'SELECT * FROM dbo.Tab_A WHERE (col1 = @par1) AND (col2 = @par2);';

WHILE @iterations > 0
BEGIN
	SET @par1 = ABS(CHECKSUM(NEWID())) % 1000
	SET	@par2 = @par1;

	-- When the parameter is < 20 we force it to 1 and we clear the cache to produce a different plan
	-- since we already know data is skewed for value 1 resulting in a table scan
	IF @par1 < 20
	BEGIN
		PRINT 'Clearing proc cache';
		ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;	-- new!
		SET @par1 = 1;
		SET @par2 = 1;
	END

	EXEC	sys.sp_executesql @sqlstmt, N'@par1 int, @par2 int', @par1, @par2
	WAITFOR DELAY '00:00:00.300';

	SET @iterations-=1;
END

SET NOCOUNT OFF;
GO

EXEC sys.sp_query_store_flush_db
GO