------------------------------------------------------------------------
--	Description:	Query store demo setup
------------------------------------------------------------------------
-- Credits: Sergio Govoni (Data Platform MVP)
-- Original article: https://blogs.msdn.microsoft.com/mvpawardprogram/2016/03/29/sql-server-2016-query-store
-- Original script: https://docs.com/sergio-govoni/6280/10-setup-querystore-database?c=ssuSrS
------------------------------------------------------------------------
USE [master];
GO

-- Create database QueryStore
CREATE DATABASE [QueryStore]
GO

-- Set recovery model to SIMPLE
ALTER DATABASE [QueryStore] SET RECOVERY SIMPLE;
ALTER DATABASE [QueryStore] SET COMPATIBILITY_LEVEL = 130;
GO

USE [QueryStore];
GO

-- Create sample table
CREATE TABLE dbo.Tab_A
(
  Col1 INTEGER
  ,Col2 INTEGER
  ,Col3 BINARY(2000)
);
GO

-- Insert some data into the sample table
SET NOCOUNT ON;
GO

BEGIN
  BEGIN TRANSACTION

  DECLARE @i INTEGER = 0;

  WHILE (@i < 10000)
  BEGIN
    INSERT INTO dbo.Tab_A (Col1, Col2) VALUES (@i, @i);
	SET @i+=1
  END

  COMMIT TRANSACTION
END;
GO

-- There are many more rows with value 1 than rows with other values
INSERT INTO dbo.Tab_A (Col1, Col2) VALUES (1, 1)
GO 100000

SET NOCOUNT OFF;
GO

-- Create indexes
CREATE INDEX IDX_Tab_A_Col1 ON dbo.Tab_A
(
  [Col1]
);
GO

CREATE INDEX IDX_Tab_A_Col2 ON dbo.Tab_A
(
  [Col2]
);
GO


DBCC SHOW_STATISTICS('dbo.Tab_A', 'IDX_Tab_A_Col1');
GO
