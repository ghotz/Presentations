--
-- Transparent Data Encryption: restore database
--

-- questo è l'errore che si verifica se non è stato ripristinato il certificato:
--
--Msg 33111, Level 16, State 3, Line 30
--Cannot find server certificate with thumbprint '0xCBAAAA3EC2A1A0F46CCA394BE42FEA56C8D106AF'.
--Msg 3013, Level 16, State 1, Line 30
--RESTORE DATABASE is terminating abnormally.
--
-- nel caso verificare quale certificato sul sistema origine
-- select * from sys.certificates

USE master;
GO

CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Passw0rd2!' -- può essere differente
GO

CREATE CERTIFICATE  DEMOTDE01
FROM FILE = 'C:\temp\demos\DEMOTDE01.cer' 
WITH PRIVATE KEY (
	FILE = 'C:\temp\demos\DEMOTDE01.private'
,	DECRYPTION BY PASSWORD = 'Passw0rd!'
);
GO

USE [master]
RESTORE DATABASE Clinic
FROM  DISK = N'C:\temp\demos\Clinic.bak'
GO
