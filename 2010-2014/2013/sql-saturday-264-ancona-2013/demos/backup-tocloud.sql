USE master;
GO
-- first of all we need a credential to access Azure Storage
CREATE CREDENTIAL AzureCredential 
WITH
	-- this is the name of the storage account
	IDENTITY= 'solidqitbackup'
	-- this should be either the Primary or Secondary Access Key for the storage account
,	SECRET = 'xxx';
GO

-- Create test database
CREATE DATABASE TestAzure
GO

-- backup to Azure Storage
-- http[s]://ACCOUNTNAME.Blob.core.windows.net/CONTAINER/FILENAME.bak
BACKUP DATABASE TestAzure 
TO URL = N'https://solidqitbackup.blob.core.windows.net/sqlbackups/TestAzure.bak' 
WITH
	CREDENTIAL = 'AzureCredential' 
,	STATS = 5;
GO 

-- show how to connect to azure storage with SSMS

-- restore database from Azure Storage
USE master;
GO
RESTORE DATABASE TestAzure
FROM  URL = N'https://solidqitbackup.blob.core.windows.net/sqlbackups/TestAzure.bak'
WITH
	CREDENTIAL = N'AzureCredential'
,	FILE = 1,  NOUNLOAD,  STATS = 5, REPLACE;
GO