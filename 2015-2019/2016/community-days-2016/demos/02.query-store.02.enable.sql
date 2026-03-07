------------------------------------------------------------------------
--	Description:	Query store demo enable
------------------------------------------------------------------------
-- Credits: Sergio Govoni (Data Platform MVP)
-- Original article: https://blogs.msdn.microsoft.com/mvpawardprogram/2016/03/29/sql-server-2016-query-store
-- Original script: https://docs.com/sergio-govoni/6280/10-setup-querystore-database?c=ssuSrS
------------------------------------------------------------------------
USE [master];
GO

-- Enables the Query Store
ALTER DATABASE [QueryStore] SET QUERY_STORE = ON
(
  -- Describes the operation mode of the query store
  OPERATION_MODE = READ_WRITE

  -- STALE_QUERY_THRESHOLD_DAYS determines the number of days for which
  -- the information for a query is retained in the query store
  ,CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 15)

  -- Set the time interval at which runtime execution statistics data
  -- is aggregated into the Query Store
  ,INTERVAL_LENGTH_MINUTES = 1

  -- Determines the frequency at which data written to the query store
  -- is persisted to disk
  ,DATA_FLUSH_INTERVAL_SECONDS = 10
);
GO
