--
-- Transparent Data Encryption: attivazione per ogni database
--
USE Clinic;
GO

CREATE DATABASE ENCRYPTION KEY
WITH ALGORITHM = AES_256
ENCRYPTION BY SERVER CERTIFICATE DEMOTDE01;
GO

--
-- Attivazione encryption
-- Controllare restrizioni: https://docs.microsoft.com/en-us/sql/relational-databases/security/encryption/transparent-data-encryption
--
ALTER DATABASE Clinic SET ENCRYPTION ON;
GO

--
-- Verifica stato encryption
--
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
