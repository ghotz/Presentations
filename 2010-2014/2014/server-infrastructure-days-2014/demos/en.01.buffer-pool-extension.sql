------------------------------------------------------------------------
--	Script:			en.01.buffer-pool-extension.sql
--	Description:	Buffer Pool Extension
--	Author:			Gianluca Hotz (SolidQ)
--	Copyright:		Attribution-NonCommercial-ShareAlike 3.0
------------------------------------------------------------------------

--	Enable advanced configuration option
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO

--	Set maximum server memory
EXEC sp_configure 'max server memory (MB)', '8192';
RECONFIGURE;
GO

--	Turn on extension
ALTER SERVER CONFIGURATION
	SET BUFFER POOL EXTENSION ON
	(FILENAME = 'D:\Caches\SQLServer.BPE', SIZE = 1GB);
GO

--	Size can't be less than "max server memory"
--	Best practice 1:16 or less (1:4 or 1:8 may be optimal)
ALTER SERVER CONFIGURATION
	SET BUFFER POOL EXTENSION ON
	(FILENAME = 'D:\Caches\SQLServer.BPE', SIZE = 10GB);
GO

--	Trying to alter definition results in error
ALTER SERVER CONFIGURATION
	SET BUFFER POOL EXTENSION ON
	(FILENAME = 'D:\Caches\SQLServer.BPE', SIZE = 12GB);
GO

--	Not a matter of file name, this still gives an error...
ALTER SERVER CONFIGURATION
	SET BUFFER POOL EXTENSION ON
	(FILENAME = 'D:\Caches\SQLServer2.BPE', SIZE = 8GB);
GO

--	Need to turn off the feature and reconfigure
ALTER SERVER CONFIGURATION
	SET BUFFER POOL EXTENSION OFF;
GO
ALTER SERVER CONFIGURATION
	SET BUFFER POOL EXTENSION ON
	(FILENAME = 'D:\Caches\SQLServer.BPE', SIZE = 12GB);
GO

--	Size can't be less than previously specified size
ALTER SERVER CONFIGURATION
	SET BUFFER POOL EXTENSION OFF;
GO
ALTER SERVER CONFIGURATION
	SET BUFFER POOL EXTENSION ON
	(FILENAME = 'D:\Caches\SQLServer.BPE', SIZE = 8GB);
GO

--	Need to turn off and restart the instance
--	net stop mssqlserver
--	net start mssqlserver
ALTER SERVER CONFIGURATION
	SET BUFFER POOL EXTENSION ON
	(FILENAME = 'D:\Caches\SQLServer.BPE', SIZE = 8GB);
GO

--
--	Buffer Pool Extension DMVs
--

--	Configuration
SELECT * FROM sys.dm_os_buffer_pool_extension_configuration;
GO

SELECT	*
FROM	sys.dm_os_buffer_descriptors
WHERE	is_in_bpool_extension = 1;
GO

--
--	Cleanup
--
ALTER SERVER CONFIGURATION
	SET BUFFER POOL EXTENSION OFF;
GO
EXEC sp_configure 'max server memory (MB)', '2147483647';
RECONFIGURE;
GO
