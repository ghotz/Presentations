--
-- Transparent Data Encryption: rimozione
--

-- Verifica quali database sono crittografati
SELECT * FROM sys.databases WHERE is_encrypted = 1
GO

USE Clinic;
GO

ALTER DATABASE Clinic SET ENCRYPTION OFF;
GO

-- Verifica stato encryption
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

--
-- Una volta finita la decifrazione di tutti i database serve
-- fare ripartire l'istanza per decifrare anche il tempdb
--

--
-- Eliminazione completa anche della chiave dal database
--
DROP DATABASE ENCRYPTION KEY;
GO

