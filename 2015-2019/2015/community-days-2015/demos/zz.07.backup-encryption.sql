------------------------------------------------------------------------
--	Script:			en.07.backup-encryption
--	Description:	SQL Server 2014 Backup Encryption
--	Author:			Gianluca Hotz (SolidQ)
--	Copyright:		Attribution-NonCommercial-ShareAlike 3.0
------------------------------------------------------------------------

--	Create test database
CREATE DATABASE TestEncDB;
GO

--	Create database master key
USE master;
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Passw0rd1';
GO

--	Create certificate to encrypt backupset
CREATE CERTIFICATE TestEncDB_BackupCert
   WITH SUBJECT = 'TestEncDB Backup Encryption Certificate';
GO

--	Perform encrypted backup
BACKUP DATABASE TestEncDB
TO DISK = N'C:\temp\TestEncDB.bak'
WITH
  COMPRESSION,
  ENCRYPTION 
   (
   ALGORITHM = AES_256,
   SERVER CERTIFICATE = TestEncDB_BackupCert
   ),
  STATS = 10
GO

--	Warning! Remember to always backup the certificate
--	because it's needed to restore the database
BACKUP CERTIFICATE TestEncDB_BackupCert
TO FILE = N'C:\temp\TestEncDB.cer'
WITH PRIVATE KEY ( FILE = N'C:\temp\TestEncDB.key' , 
ENCRYPTION BY PASSWORD = 'Passw0rd1' );
GO

--	Simulate disaster or restore to another instance
DROP DATABASE TestEncDB
GO
DROP CERTIFICATE TestEncDB_BackupCert
GO

--	Try restoring without a certificate will not work!
RESTORE DATABASE TestEncDB
FROM  DISK = N'C:\temp\TestEncDB.bak'
WITH  FILE = 1,  NOUNLOAD,  STATS = 5
GO

--	Restore certificate first
CREATE CERTIFICATE TestEncDB_BackupCert 
FROM FILE = N'C:\temp\TestEncDB.cer'
WITH PRIVATE KEY ( FILE = N'C:\temp\TestEncDB.key' , 
DECRYPTION BY PASSWORD = 'Passw0rd1' );
GO

--	Finally restore the database
RESTORE DATABASE TestEncDB
FROM  DISK = N'C:\temp\TestEncDB.bak'
WITH  FILE = 1,  NOUNLOAD,  STATS = 5
GO

--
-- Cleanup
--
DROP DATABASE TestEncDB
GO
DROP CERTIFICATE TestEncDB_BackupCert
GO