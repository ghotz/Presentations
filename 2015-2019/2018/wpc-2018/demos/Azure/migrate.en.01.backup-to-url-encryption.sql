------------------------------------------------------------------------
-- Copyright:   2018 Gianluca Hotz
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
--
-- Synopsis:	Migration to SQL Azure Database by a simple
--              backup/restore using Blob Storage.
--              
--              This script needs to be run on the source system.
-- Credits:     
------------------------------------------------------------------------
-- Search/replace paths in this script:
--
-- Default paths:       https://azurebackupsdemo.blob.core.windows.net/sqlbackups
------------------------------------------------------------------------
USE master;
GO

-- We need to create the Shared Access Signature with a credential name
-- matching the storage account and container names
IF EXISTS(SELECT * FROM sys.credentials WHERE name = 'https://azurebackupsdemo.blob.core.windows.net/sqlbackups')
	DROP CREDENTIAL [https://azurebackupsdemo.blob.core.windows.net/sqlbackups];
GO
CREATE CREDENTIAL [https://azurebackupsdemo.blob.core.windows.net/sqlbackups]
WITH
	IDENTITY= 'SHARED ACCESS SIGNATURE'
	--	this needs to be a SAS without the initial ? character
,	SECRET = '<INSERT SAS HERE>'
GO

--	Perform encrypted backup
BACKUP DATABASE AdventureWorksLT2012
TO URL = N'https://azurebackupsdemo.blob.core.windows.net/sqlbackups/AdventureWorksLT2012.bak' 
WITH
	COMPRESSION, CHECKSUM, INIT, STATS = 10;
GO
