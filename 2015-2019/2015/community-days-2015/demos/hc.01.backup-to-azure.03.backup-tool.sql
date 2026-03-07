------------------------------------------------------------------------
--	Description:	Backup to Azure: Backup with Windows Azure Tool
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
CREATE DATABASE TestAzure;
GO

------------------------------------------------------------------------
-- to test the backup tool configure it to get backup sets
-- from C:\temp\backuptool\*.bak and do a local backup
-- don't use compression as the tool already compress the sets
--
--	"C:\Program Files\Microsoft SQL Server Backup to Windows Azure Tool\SQLBackup2AzureConfig.exe"
------------------------------------------------------------------------
BACKUP DATABASE TestAzure 
TO DISK = N'C:\temp\backuptool\TestAzure.bak' 
WITH
	CHECKSUM, STATS = 5, INIT;
GO

-- verify that the local backupset is only metadata
-- by opening it in notepad.exe C:\temp\backuptool\TestAzure.bak

-- try restoring from the metadata file
USE master;
GO
RESTORE DATABASE TestAzure
FROM DISK = N'C:\temp\backuptool\TestAzure.bak'
WITH
	STATS = 5, CHECKSUM, REPLACE;
GO

-- also restore verifyonly works
RESTORE VERIFYONLY
FROM DISK = N'C:\temp\backuptool\TestAzure.bak';
GO

------------------------------------------------------------------------
--	General note: in a disaster recovery scenario with a VM, you need
--	to install the Microsoft SQL Server BACKUP to Microsoft Azure Tool
--	also on the VM to be able to restore from the metadata-only
--	backup set file, another option is to copy the *.gz file,
--	decompress it and use the backup set
------------------------------------------------------------------------
