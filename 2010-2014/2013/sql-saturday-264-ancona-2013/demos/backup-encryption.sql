-- Create test database
CREATE DATABASE [TestEncDB]
GO

-- Create database master key
USE master;
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Passw0rd1';
GO

-- Create certificate to encrypt backupset
CREATE CERTIFICATE TestEncDB_BackupCert
   WITH SUBJECT = 'TestEncDB Backup Encryption Certificate';
GO

-- Perform encrypted backup
BACKUP DATABASE [TestEncDB]
TO DISK = N'C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\Backup\TestEncDB.bak'
WITH
  COMPRESSION,
  ENCRYPTION 
   (
   ALGORITHM = AES_256,
   SERVER CERTIFICATE = TestEncDB_BackupCert
   ),
  STATS = 10
GO

-- Warning! Remember to always backup the certificate
-- because it's needed to restore the database
BACKUP CERTIFICATE TestEncDB_BackupCert
TO FILE = N'C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\Backup\TestEncDB.cer'
WITH PRIVATE KEY ( FILE = N'C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\Backup\TestEncDB.key' , 
ENCRYPTION BY PASSWORD = 'Passw0rd1' );
GO

-- simulate disaster or restore to another instance
DROP DATABASE [TestEncDB]
GO
DROP CERTIFICATE TestEncDB_BackupCert
GO

-- try restoring without a certificate will not work!
RESTORE DATABASE [TestEncDB]
FROM  DISK = N'C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\Backup\TestEncDB.bak'
WITH  FILE = 1,  NOUNLOAD,  STATS = 5
GO

-- restore certificate
CREATE CERTIFICATE TestEncDB_BackupCert 
FROM FILE = N'C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\Backup\TestEncDB.cer'
WITH PRIVATE KEY ( FILE = N'C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\Backup\TestEncDB.key' , 
DECRYPTION BY PASSWORD = 'Passw0rd1' );
GO

-- finally restore database
RESTORE DATABASE [TestEncDB]
FROM  DISK = N'C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\Backup\TestEncDB.bak'
WITH  FILE = 1,  NOUNLOAD,  STATS = 5
GO

-- Perform encrypted backup on Azure
BACKUP DATABASE [TestEncDB]
TO URL = N'https://solidqitbackup.blob.core.windows.net/sqlbackups/TestEncDB.bak'
WITH
	COMPRESSION
,	CREDENTIAL = 'AzureCredential' 
,	ENCRYPTION 
   (
   ALGORITHM = AES_256,
   SERVER CERTIFICATE = TestEncDB_BackupCert
   ),
  STATS = 10
GO