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
--              This script needs to be run on the source system.
-- Credits:     
------------------------------------------------------------------------
-- Search/replace paths in this script:
--
-- Default paths:       c:\temp\demos
------------------------------------------------------------------------
USE master;
GO

------------------------------------------------------------------------
-- TDE Activation
------------------------------------------------------------------------
--	Database Master Key creation
USE master;
GO
IF EXISTS (SELECT * FROM sys.symmetric_keys WHERE symmetric_key_id = 102)
	DROP MASTER KEY;
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Passw0rd1';
GO

-- TDE Certificate creation
IF EXISTS(SELECT * FROM sys.certificates WHERE name = 'TDEDemoCert')
	DROP CERTIFICATE TDEDemoCert;
CREATE CERTIFICATE TDEDemoCert
WITH	SUBJECT = 'Transparent Data Encryption Certificate for SQL Server instances'
,		EXPIRY_DATE = '20380115';	-- Friday
GO

-- Backup certificate
BACKUP CERTIFICATE TDEDemoCert
TO FILE = N'C:\Temp\demos\TDEDemoCert.cer'
WITH PRIVATE KEY ( FILE = N'C:\Temp\demos\TDEDemoCert.pvk' , 
ENCRYPTION BY PASSWORD = 'Passw0rd1' );
GO

USE AdventureWorksLT;
GO

CREATE DATABASE ENCRYPTION KEY
WITH ALGORITHM = AES_256
ENCRYPTION BY SERVER CERTIFICATE TDEDemoCert;
GO

--
-- Encryption activation
-- Check restrictions: https://docs.microsoft.com/en-us/sql/relational-databases/security/encryption/transparent-data-encryption
--
ALTER DATABASE AdventureWorksLT SET ENCRYPTION ON;
GO

-- Check encryption status
SELECT 
	DB_NAME(database_id) AS DatabaseName
,	CASE encryption_state
			WHEN 1 THEN 'Unencrypted'
			WHEN 2 THEN 'Encryption in progress'
			WHEN 3 THEN 'Encrypted'
			WHEN 4 THEN 'Key change in progress'
			WHEN 5 THEN 'Decryption in progress'
		END	AS DatabaEncryptionStatus
,	percent_complete
FROM	sys.dm_database_encryption_keys;
GO

------------------------------------------------------------------------
-- Backup to disk (encrypted by TDE)
------------------------------------------------------------------------

--	Perform encrypted backup
BACKUP DATABASE AdventureWorksLT
TO DISK = 'AdventureWorksLT.bak' 
WITH
	COMPRESSION, CHECKSUM, FORMAT, STATS = 10;
GO

------------------------------------------------------------------------
-- Simulate complete disaster or restore to a different machine wihtout
-- the certificate installed
------------------------------------------------------------------------
USE master;
GO
DROP DATABASE AdventureWorksLT;
GO
DROP CERTIFICATE TDEDemoCert;
GO

-- Let's try to restore the database...
RESTORE DATABASE AdventureWorksLT
FROM DISK = 'AdventureWorksLT.bak' 
WITH
	CHECKSUM, STATS = 10;
GO

-- ...without the certificate, restore fails with error
--
-- Msg 33111, Level 16, State 3, Line 117
-- Cannot find server certificate with thumbprint '0x530CC734969589B95BF7D7B9343048BC45AA38BE'.
-- Msg 3013, Level 16, State 1, Line 117
-- RESTORE DATABASE is terminating abnormally.

-- Restore certificate first (very important to keep it safe)
CREATE CERTIFICATE  TDEDemoCert
FROM FILE = 'C:\temp\demos\TDEDemoCert.cer' 
WITH PRIVATE KEY (
	FILE = 'C:\temp\demos\TDEDemoCert.pvk'
,	DECRYPTION BY PASSWORD = 'Passw0rd1'
);
GO

-- Now we can restore (certificate is matched by thumbprint)
RESTORE DATABASE AdventureWorksLT
FROM DISK = 'AdventureWorksLT.bak' 
WITH
	CHECKSUM, STATS = 10;
GO

------------------------------------------------------------------------
-- Cleanup
------------------------------------------------------------------------

-- Turn TDE off
ALTER DATABASE AdventureWorksLT SET ENCRYPTION OFF;
GO

-- Check decryption status
SELECT 
	DB_NAME(database_id) AS DatabaseName
,	CASE encryption_state
			WHEN 1 THEN 'Unencrypted'
			WHEN 2 THEN 'Encryption in progress'
			WHEN 3 THEN 'Encrypted'
			WHEN 4 THEN 'Key change in progress'
			WHEN 5 THEN 'Decryption in progress'
		END	AS DatabaEncryptionStatus
,	percent_complete
FROM	sys.dm_database_encryption_keys;
GO

-- NOTE: to turn off encryption from tempdb, we need to remove it
-- from all user databases and restart the instance

-- Remove database encryption key
USE AdventureWorksLT;
GO
DROP DATABASE ENCRYPTION KEY;
GO

-- Remove the certificate
USE master;
GO
IF EXISTS(SELECT * FROM sys.certificates WHERE name = 'TDEDemoCert')
	DROP CERTIFICATE TDEDemoCert;
GO

-- Finally remove the instance master key
IF EXISTS (SELECT * FROM sys.symmetric_keys WHERE symmetric_key_id = 102)
	DROP MASTER KEY;
GO
