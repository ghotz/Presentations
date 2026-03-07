------------------------------------------------------------------------
--	Description:	Failover to Azure VM: DR scenario
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

------------------------------------------------------------------------
--	Start the workload with SQLQueryStress
--	hc.02.test-dr-failover.04.workload.sqlstress
------------------------------------------------------------------------

------------------------------------------------------------------------
--	Verify inserts
------------------------------------------------------------------------

SELECT	C1, COUNT(*) AS num_inserts
FROM	TestAzure.dbo.T1
GROUP BY C1;
GO


------------------------------------------------------------------------
--	Backup database to Azure Blob Service
------------------------------------------------------------------------
BACKUP DATABASE TestAzure 
TO URL = N'https://hcdemo.blob.core.windows.net/sqlbackups/TestAzure.bak' 
WITH
	CREDENTIAL = 'AzureCredential',	COMPRESSION,  CHECKSUM, STATS = 5, FORMAT;
GO 

------------------------------------------------------------------------
--	Pretend that a fail occured on-premise
------------------------------------------------------------------------

------------------------------------------------------------------------
--	Switch the alias with the PowerShell script (admin rights!)
--	hc.02.test-dr-failover.05.change-alias.ps1
--
--	Note the errors connecting because the database doesn't exist
------------------------------------------------------------------------

------------------------------------------------------------------------
--	Restore the database on the VM using SSMS
------------------------------------------------------------------------

------------------------------------------------------------------------
--	Note that the errors stopped and verify inserts on the VM
------------------------------------------------------------------------
SELECT	C1, COUNT(*) AS num_inserts
FROM	TestAzure.dbo.T1
GROUP BY C1;
GO

------------------------------------------------------------------------
-- In a real scenario, the time to fail-over depends on several factors:
--	1) machine provisioning time (if not already provisioned)
--	2) machine start-up time (if not already running ie. if deallocated)
--	3) restore time (if not using other live synch mechanism
--	   eg. log shipping, mirroring, Availability Groups)
--	4) script to apply to synchronize logins/jobs or any other
--	   collateral object
------------------------------------------------------------------------

------------------------------------------------------------------------
--	Optional: if you run the hc.01.backup-to-azure.03.backup-tool.sql
--	demo, you can show also how to restore from the metadata only
--	*.bak file
------------------------------------------------------------------------
