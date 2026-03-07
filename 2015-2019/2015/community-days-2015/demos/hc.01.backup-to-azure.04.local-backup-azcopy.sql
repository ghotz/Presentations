------------------------------------------------------------------------
--	Description:	Backup to Azure: local backup and copy with azcopy
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

--	create a test database
IF EXISTS(SELECT * FROM sys.databases WHERE name = 'TestAzure')
	DROP DATABASE TestAzure;
GO
CREATE DATABASE TestAzure
ALTER DATABASE TestAzure SET RECOVERY FULL;
GO

------------------------------------------------------------------------
--	backup to local folder
--
--	Remember to use the option BLOCKSIZE=65536 to prevent error:
--	Msg 3268, Level 16, State 1, Line 1
--	Cannot use the backup file
--	'https://hcdemo.blob.core.windows.net/sqlbackups/TestAzure-Full.bak'
--	because it was originally formatted with sector size 512 and is now
--	on a device with sector size 65536.
------------------------------------------------------------------------
BACKUP DATABASE TestAzure 
TO DISK = N'C:\temp\TestAzure-Full.bak'
WITH BLOCKSIZE=65536, COMPRESSION, CHECKSUM, STATS = 10, FORMAT;
GO 
BACKUP LOG TestAzure 
TO DISK = N'C:\temp\TestAzure-Log.bak'
WITH BLOCKSIZE=65536, COMPRESSION, CHECKSUM, STATS = 10, FORMAT;
GO 

------------------------------------------------------------------------
--	run azcopy batch hc.01.backup-to-azure.05.local-backup-azcopy.bat
--	and show restore via SSMS on remote VM
------------------------------------------------------------------------
