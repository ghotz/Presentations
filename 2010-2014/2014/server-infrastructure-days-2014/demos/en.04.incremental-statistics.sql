------------------------------------------------------------------------
--	Script:			en.04.incremental-statistics.sql
--	Description:	Incremental Statistics
--	Author:			Gianluca Hotz (SolidQ)
--	Copyright:		Attribution-NonCommercial-ShareAlike 3.0
------------------------------------------------------------------------

--	Based on examples in Benjamin Nevarez article on http://www.sqlperformance.com
--	"SQL Server 2014 Incremental Statistics"
--	http://www.sqlperformance.com/2014/02/sql-statistics/2014-incremental-statistics

--	Revert any changes to original compatibility level
ALTER DATABASE AdventureWorks2012
SET COMPATIBILITY_LEVEL = 110;
GO
USE AdventureWorks2012;
GO

--	Create partition function
CREATE PARTITION FUNCTION TransactionRangePF1 (DATETIME)
AS RANGE RIGHT FOR VALUES 
(
   '20071001', '20071101', '20071201', '20080101', 
   '20080201', '20080301', '20080401', '20080501', 
   '20080601', '20080701', '20080801'
);
GO

--	Create partition scheme 
CREATE PARTITION SCHEME TransactionsPS1 AS PARTITION TransactionRangePF1 TO 
(
  [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], 
  [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], 
  [PRIMARY], [PRIMARY], [PRIMARY]
);
GO
 
--	Create test table
CREATE TABLE dbo.TransactionHistory 
(
  TransactionID        INT      NOT NULL, -- not bothering with IDENTITY here
  ProductID            INT      NOT NULL,
  ReferenceOrderID     INT      NOT NULL,
  ReferenceOrderLineID INT      NOT NULL DEFAULT (0),
  TransactionDate      DATETIME NOT NULL DEFAULT (GETDATE()),
  TransactionType      NCHAR(1) NOT NULL,
  Quantity             INT      NOT NULL,
  ActualCost           MONEY    NOT NULL,
  ModifiedDate         DATETIME NOT NULL DEFAULT (GETDATE()),
  CONSTRAINT CK_TransactionType 
    CHECK (UPPER(TransactionType) IN (N'W', N'S', N'P'))
) 
ON TransactionsPS1 (TransactionDate);
GO

--	Insert data for first 11 partitions out of 12
INSERT	dbo.TransactionHistory
SELECT	*
FROM	Production.TransactionHistory
WHERE	TransactionDate < '2008-08-01';
GO

--	Create incremental statistics for Transaction Date
CREATE STATISTICS stats_TransactionHistory_TransactionDate
ON dbo.TransactionHistory(TransactionDate) 
	WITH FULLSCAN, INCREMENTAL = ON;
GO

--	Check histogram, we already have 200 steps
DBCC SHOW_STATISTICS('dbo.TransactionHistory', stats_TransactionHistory_TransactionDate);
GO

--	Insert data in 12th partition
INSERT	dbo.TransactionHistory 
SELECT	*
FROM	Production.TransactionHistory 
WHERE	TransactionDate >= '2008-08-01';
GO

--	Check histogram, last steps are the same
DBCC SHOW_STATISTICS('dbo.TransactionHistory', stats_TransactionHistory_TransactionDate);
GO

--	Update only statistics for last partition
UPDATE STATISTICS dbo.TransactionHistory(stats_TransactionHistory_TransactionDate) 
  WITH RESAMPLE ON PARTITIONS(12);
GO

--	Check histogram, last step was updated
DBCC SHOW_STATISTICS('dbo.TransactionHistory', stats_TransactionHistory_TransactionDate);
GO

--	Disable incremental statistics
UPDATE STATISTICS dbo.TransactionHistory(stats_TransactionHistory_TransactionDate) 
  WITH FULLSCAN, INCREMENTAL = OFF;
GO

--
--	Cleanup
--
IF OBJECT_ID('dbo.TransactionHistory ') IS NOT NULL
	DROP TABLE dbo.TransactionHistory;
GO

DROP PARTITION SCHEME TransactionsPS1;
GO

DROP PARTITION FUNCTION TransactionRangePF1;
GO