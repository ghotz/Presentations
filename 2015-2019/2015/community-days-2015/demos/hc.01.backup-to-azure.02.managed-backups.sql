------------------------------------------------------------------------
--	Description:	Backup to Azure: Managed Backups
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
IF EXISTS(SELECT * FROM sys.databases WHERE name = 'TestAzureManaged')
	DROP DATABASE TestAzureManaged;
GO
CREATE DATABASE TestAzureManaged
GO

------------------------------------------------------------------------
--	The master switch alows to enable/disable managed backups
------------------------------------------------------------------------
EXEC	msdb.smart_admin.sp_backup_master_switch @new_state  = 1;
GO

------------------------------------------------------------------------
--	Add exsting database to managed backups
------------------------------------------------------------------------

--	only databases in FULL of BULK recovery model can be backed up
ALTER DATABASE TestAzureManaged SET RECOVERY FULL;
GO
--	note: you pass the storage account URL, inside a container with
--	the computer name is automatically created by managed backups
EXEC	msdb.smart_admin.sp_set_db_backup 
			@enable_backup = 1
		,	@database_name='TestAzureManaged' 
		,	@retention_days=30 
		,	@credential_name='AzureCredential'
		,	@storage_url = N'https://hcdemo.blob.core.windows.net'
		,	@encryption_algorithm = N'NO_ENCRYPTION', @encryptor_type = N'', @encryptor_name = N'';
GO 

--	verify configuration
SELECT * FROM msdb.smart_admin.fn_backup_db_config('TestAzureManaged');
GO

--	curently there's no way to clean the metadata so you may find
--	several old configuration rows for the same database name
--	you can filter by is_dropped to find the current one
SELECT	*
FROM	msdb.smart_admin.fn_backup_db_config('TestAzureManaged')
WHERE	is_dropped = 0;
GO

--	if we don't have any backup yet, it may take up to 15 mins
--	also, the view may return previous dirty metadata until the
--	
--	NOTE: before SQL Server 2014 CU5 backups may not start because
--	of error 242 http://support.microsoft.com/kb/3014359
SELECT * FROM msdb.smart_admin.fn_available_backups('TestAzureManaged');
GO

--	we can also query the regular DMVs
SELECT	B1.db_name, B2.backup_start_date
,		B2.[type] AS backup_type, B3.physical_device_name
FROM	msdb.smart_admin.fn_backup_db_config('TestAzureManaged') AS B1
LEFT
JOIN	msdb.dbo.backupset AS B2
  ON	B1.db_guid = B2.database_guid
LEFT
JOIN	msdb.dbo.backupmediafamily AS B3
  ON	B2.media_set_id = B3.media_set_id
WHERE	B1.is_dropped = 0
ORDER BY
		B2.backup_start_date;
GO

--	since we can't wait for 15 mins :) let's force a backup on-demand
EXEC	msdb.smart_admin.sp_backup_on_demand
			@database_name = 'TestAzureManaged'
		,	@type = 'Database';
GO

--	on-demand backups don't break the log chain and are not part of the
--	regular maintenance, please note the expiration date
SELECT * FROM msdb.smart_admin.fn_available_backups('TestAzureManaged');
GO

-- let's start doing some modification
IF OBJECT_ID('TestAzureManaged.dbo.T1') IS NOT NULL
	DROP TABLE TestAzureManaged.dbo.T1;
CREATE TABLE TestAzureManaged.dbo.T1(f1 VARCHAR(8000) NOT NULL);
GO
SET NOCOUNT ON;
BEGIN TRANSACTION
	DECLARE	@n INT = 1000;
	WHILE @n > 0
	BEGIN
		INSERT TestAzureManaged.dbo.T1 VALUES (REPLICATE('A', 8000));
		SET @n -= 1;
	END
COMMIT TRANSACTION
SET NOCOUNT OFF;
GO

--	the log backup will be done and show up only if the regular
--	maintenance has begun with a FULL backup previously
--	as we did before, we can take a on-demand log backup
EXEC msdb.smart_admin.sp_backup_on_demand @database_name = 'TestAzureManaged', @type = 'Log';
GO

--	this will show up immediately
SELECT * FROM msdb.smart_admin.fn_available_backups('TestAzureManaged');
GO

------------------------------------------------------------------------
--	Managed backups instance-wide configuration
--
--	The problem with the previous approach is that the DBA needs to
--	add manually new databases, instead managed backups can be
--	configured at the instance level so that newly created databases
--	will be automatically added.
------------------------------------------------------------------------
EXEC	msdb.smart_admin.sp_set_instance_backup
			@enable_backup = 1
		,	@retention_days = 30
		,	@credential_name = N'AzureCredential'
		,	@storage_url = N'https://hcdemo.blob.core.windows.net'
		,	@encryption_algorithm = N'NO_ENCRYPTION', @encryptor_type = N'', @encryptor_name = N'';
GO

--	verify configuration
SELECT * FROM msdb.smart_admin.fn_backup_instance_config();
GO

--	if you had any other database on the instance when you
--	turned on managed backups at the instance level, you still
--	have to add them manually as they will show up as not managed 
SELECT	*
FROM	msdb.smart_admin.fn_backup_db_config(default)
WHERE	is_managed_backup_enabled = 0 OR is_managed_backup_enabled IS NULL;
GO

--	however, if you add a new database...
IF EXISTS(SELECT * FROM sys.databases WHERE name = 'TestAzureManagedNew')
	DROP DATABASE TestAzureManagedNew;
GO
CREATE DATABASE TestAzureManagedNew;
GO

--	...it will be added as managed with the defaults specified...
SELECT	*
FROM	msdb.smart_admin.fn_backup_db_config('TestAzureManagedNew')
WHERE	is_dropped = 0;
GO

--	NULL? why? remember recovery model needs to be FULL or BULK_LOGGED
ALTER DATABASE TestAzureManagedNew SET RECOVERY FULL;
GO

--	at some point the new config will be picked up
SELECT	*
FROM	msdb.smart_admin.fn_backup_db_config('TestAzureManagedNew')
WHERE	is_dropped = 0;
GO

------------------------------------------------------------------------
--	Diagnostics procedures/DMVs
------------------------------------------------------------------------
SELECT * FROM msdb.smart_admin.fn_get_health_status(DEFAULT, DEFAULT);
SELECT * FROM msdb.smart_admin.fn_get_current_xevent_settings();
EXEC msdb.smart_admin.sp_get_backup_diagnostics;	-- last 30 mins by default
GO

------------------------------------------------------------------------
--	Switch everything off
------------------------------------------------------------------------
EXEC	msdb.smart_admin.sp_backup_master_switch @new_state  = 0;
EXEC	msdb.smart_admin.sp_set_instance_backup @enable_backup = 0;
EXEC	msdb.smart_admin.sp_set_db_backup @database_name='TestAzureManaged', @enable_backup = 0;
EXEC	msdb.smart_admin.sp_set_db_backup @database_name='TestAzureManagedNew', @enable_backup = 0
GO
--	metadata is still there :-(
SELECT * FROM msdb.smart_admin.fn_backup_db_config(default);
GO

