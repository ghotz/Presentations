------------------------------------------------------------------------
-- Copyright:   2022 Gianluca Hotz
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
-- Credits:     Bob Ward 
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Demo: Cardinality Estimator feedback
------------------------------------------------------------------------
USE [AdventureWorks2016_EXT];
GO

-- create extended events session
IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = 'CEFeedback')
	DROP EVENT SESSION [CEFeedback] ON SERVER;
GO
CREATE EVENT SESSION [CEFeedback] ON SERVER
ADD EVENT sqlserver.query_feedback_analysis(
	ACTION(sqlserver.query_hash_signed,sqlserver.query_plan_hash_signed,sqlserver.sql_text)),
ADD EVENT sqlserver.query_feedback_validation(
	ACTION(sqlserver.query_hash_signed,sqlserver.query_plan_hash_signed,sqlserver.sql_text))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=NO_EVENT_LOSS,MAX_DISPATCH_LATENCY=1 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=OFF);
GO
-- Start XE
ALTER EVENT SESSION [CEFeedback] ON SERVER STATE = START;
GO

-- create index 
-- DROP INDEX [IX_Address_City] ON [Person].[Address]
CREATE NONCLUSTERED INDEX [IX_Address_City]
ON [Person].[Address] ([City] ASC);
GO

-- Set SQL Server 2022 compatibilty level and clear Query Store
ALTER DATABASE [AdventureWorks2016_EXT] SET COMPATIBILITY_LEVEL = 160;
ALTER DATABASE [AdventureWorks2016_EXT] SET QUERY_STORE = ON;
ALTER DATABASE [AdventureWorks2016_EXT] SET QUERY_STORE (OPERATION_MODE = READ_WRITE);
ALTER DATABASE [AdventureWorks2016_EXT] SET QUERY_STORE CLEAR;
GO

-- clear cache
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

-- run query 15 times (don't rely on magic numbers!)
SELECT AddressLine1, City, PostalCode FROM Person.Address
WHERE StateProvinceID = 79 AND City = 'Redmond';
GO 15

-- run one more time and...
SELECT AddressLine1, City, PostalCode FROM Person.Address
WHERE StateProvinceID = 79 AND City = 'Redmond';
GO

-- ...check Extended Events session

-- verify Query Store hint, it's not there yet
SELECT * from sys.query_store_query_hints;
GO
-- it's pending validation
SELECT * from sys.query_store_plan_feedback;
GO

-- run one more time and...
SELECT AddressLine1, City, PostalCode FROM Person.Address
WHERE StateProvinceID = 79 AND City = 'Redmond';
GO

-- ...check Extended Events session (time)

-- verify Query Store hint, now it's there
SELECT * from sys.query_store_query_hints;
GO
-- and verification is passed
SELECT * from sys.query_store_plan_feedback;
GO

-- run again the batch and compare plan (2 secs.)
SELECT AddressLine1, City, PostalCode FROM Person.Address
WHERE StateProvinceID = 79 AND City = 'Redmond';
GO 15

-- Verify in Query Store plan change and timings
