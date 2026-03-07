------------------------------------------------------------------------
--	Script:			en.05.online-operations.sql
--	Description:	Online Operations
--	Author:			Gianluca Hotz (SolidQ)
--	Copyright:		Attribution-NonCommercial-ShareAlike 3.0
------------------------------------------------------------------------

--	Partition table code based on examples in Benjamin Nevarez article
--	"SQL Server 2014 Incremental Statistics"
--	http://www.sqlperformance.com/2014/02/sql-statistics/2014-incremental-statistics

--	Revert any changes to original compatibility level
ALTER DATABASE AdventureWorks2012
SET COMPATIBILITY_LEVEL = 120;
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

--	Find partition information
SELECT * FROM sys.partitions WHERE object_id = OBJECT_ID('dbo.TransactionHistory');
GO

--	Rebuild 
ALTER TABLE dbo.TransactionHistory
REBUILD PARTITION = 12
WITH (ONLINE = ON);
GO

--	Run the following code in a second connection
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN TRANSACTION;
	SELECT COUNT(*) FROM dbo.TransactionHistory;
GO

--	Try running the above code again
ALTER TABLE dbo.TransactionHistory
REBUILD PARTITION = 12
WITH (ONLINE = ON);
GO

--	We are waiting, run the following code in a third connection
EXEC sp_lock;
SELECT * FROM sys.dm_tran_locks;
GO

--	Abort running the rebuild command

--	Try again specifying lock priority killing the rebuild
--	after waiting for 1 minute
ALTER TABLE dbo.TransactionHistory
REBUILD PARTITION = 12
WITH (ONLINE = ON (WAIT_AT_LOW_PRIORITY(MAX_DURATION = 1 MINUTES, ABORT_AFTER_WAIT = SELF)));
GO

--	The command will fail with the following error
--	Msg 1222, Level 16, State 56, Line 90
--	Lock request time out period exceeded.

--	Try again specifying lock priority killing blockers
--	after waiting for 1 minute
ALTER TABLE dbo.TransactionHistory
REBUILD PARTITION = 12
WITH (ONLINE = ON (WAIT_AT_LOW_PRIORITY(MAX_DURATION = 1 MINUTES, ABORT_AFTER_WAIT = BLOCKERS)));
GO

--	The rebuild command will succeed while the transaction
--	in the second connection will fail

--	One important thing to understamd is that the below statement allows
--	other connections to still acquire locks for 1 minute while the DDL
--	command is in the low priority queue
ALTER TABLE dbo.TransactionHistory
REBUILD PARTITION = 12
WITH (ONLINE = ON (WAIT_AT_LOW_PRIORITY(MAX_DURATION = 1 MINUTES, ABORT_AFTER_WAIT = NONE)));
GO

--
--	Cleanup
--
IF @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;
GO

IF OBJECT_ID('dbo.TransactionHistory ') IS NOT NULL
	DROP TABLE dbo.TransactionHistory;
GO

DROP PARTITION SCHEME TransactionsPS1;
GO

DROP PARTITION FUNCTION TransactionRangePF1;
GO