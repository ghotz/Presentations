------------------------------------------------------------------------
--	Description:	Backup to Azure: simple backup to URL
------------------------------------------------------------------------
--	Copyright (c) 2015 Gianluca Hotz
--	Permission is hereby granted, free of charge, to any person
--	obtaining a copy of this software and associated documentation files
--	(the "Software"), to deal in the Software without restriction,
--	including without limitation the rights to use, copy, modify, merge,
--	publish, distribute, sublicense, and/or sell copies of the Software,
--	and to permit persons to whom the Software is furnished to do so,
--	subject to the following conditions:
--	The above copyright notice and this permission notice shall be
--	included in all copies or substantial portions of the Software.
--	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
--	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
--	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
--	NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
--	BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
--	ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
--	CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--	SOFTWARE.
------------------------------------------------------------------------
USE master;
GO

------------------------------------------------------------------------
--	Environment Setup
------------------------------------------------------------------------

--	first of all we need a credential to access Azure Storage
IF EXISTS(SELECT * FROM sys.credentials WHERE name = 'AzureCredential')
	DROP CREDENTIAL AzureCredential;
GO

CREATE CREDENTIAL AzureCredential
WITH
	--	this is the name of the storage account
	IDENTITY= 'hcdemo'
	--	this should be either the Primary or Secondary Access Key for the storage account
,	SECRET = '<INSERT KEY HERE>';
GO

--	create a test database
IF EXISTS(SELECT * FROM sys.databases WHERE name = 'TestAzure')
	DROP DATABASE TestAzure;
GO
CREATE DATABASE TestAzure
GO

------------------------------------------------------------------------
--	backup to Azure Storage
--	http[s]://ACCOUNTNAME.Blob.core.windows.net/CONTAINER/FILENAME.bak
------------------------------------------------------------------------
BACKUP DATABASE TestAzure 
TO URL = N'https://hcdemo.blob.core.windows.net/sqlbackups/TestAzure.bak' 
WITH
	CREDENTIAL = 'AzureCredential',	COMPRESSION, CHECKSUM, STATS = 5;
GO 

--	backup sets can't be appended, WITH FORMAT needed to overwrite a set
BACKUP DATABASE TestAzure 
TO URL = N'https://hcdemo.blob.core.windows.net/sqlbackups/TestAzure.bak' 
WITH
	CREDENTIAL = 'AzureCredential',	COMPRESSION,  CHECKSUM, STATS = 5, FORMAT;
GO 

------------------------------------------------------------------------
-- restore database from Azure Storage
------------------------------------------------------------------------
USE master;
GO
RESTORE DATABASE TestAzure
FROM  URL = N'https://hcdemo.blob.core.windows.net/sqlbackups/TestAzure.bak'
WITH
	CREDENTIAL = N'AzureCredential', STATS = 5, CHECKSUM, REPLACE;
GO

--	Restore verifyonly works as expected
--	Note: on build 12.0.2430 (CU4) it systematically leaves the lease
--	active in build 12.0.2480 it works as expected (CU6, probably
--	fixed in CU5), see the following KB article to remove the lease
--	https://msdn.microsoft.com/en-us/library/jj919145.aspx
RESTORE VERIFYONLY
FROM URL = N'https://hcdemo.blob.core.windows.net/sqlbackups/TestAzure.bak'
WITH
	CREDENTIAL = N'AzureCredential', CHECKSUM, STATS = 5;
GO

------------------------------------------------------------------------
--	Show storage account in SSMS and Azure Explorer
------------------------------------------------------------------------
