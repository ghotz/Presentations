--
-- Transparent Data Encryption: inizializzazione
--

--
-- Creazione Master Key a livello di istanza
--
USE master;  
GO  
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Passw0rd!';  
GO 

--
-- Creazione certificato che proteggerà le database encryption keys
--
CREATE CERTIFICATE DEMOTDE01
WITH	SUBJECT = 'Transparent Data Encryption Certificate for SQL Server instances'
,		EXPIRY_DATE = '20380115';	-- Friday
GO

--
-- Backup certificato
--
BACKUP CERTIFICATE DEMOTDE01
TO FILE = 'C:\Temp\demos\DEMOTDE01.cer'
WITH PRIVATE KEY 
( 
	FILE = 'C:\Temp\demos\DEMOTDE01.private'
,	ENCRYPTION BY PASSWORD = 'Passw0rd!' 
);
GO
