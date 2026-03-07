USE Northwind
GO

-- aggiunta login ed utenti
EXEC	sp_addlogin N'pippo'
EXEC	sp_addlogin N'pluto'
EXEC	sp_addlogin N'paperoga'
GO

EXEC	sp_grantdbaccess N'pippo', N'pippo'
EXEC	sp_grantdbaccess N'pluto', N'pluto'
EXEC	sp_grantdbaccess N'paperoga', N'paperoga'

-- verifico la mia identita'
SELECT SUSER_SNAME()
GO

-- Ritorno ad essere l'utente che ha effettuato la connessione
SETUSER
GO

-- Abilito i permessi di creazione tabelle e viste
-- a pippo e pluto
GRANT CREATE TABLE TO pippo
GRANT CREATE VIEW TO pippo
GRANT CREATE VIEW TO pluto
GO

-- impersonifico pippo
SETUSER 'pippo'
GO
SELECT SUSER_SNAME()

-- pippo crea una tabella
IF EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'pippo' AND TABLE_NAME = 'Tabella1' AND TABLE_TYPE = 'BASE TABLE')
	DROP TABLE pippo.tabella1

CREATE TABLE pippo.tabella1 (
	MyID	int		NOT NULL IDENTITY(1, 1)	PRIMARY KEY,
	MyDate	datetime	NOT NULL DEFAULT (GETDATE())
)
GO

-- inserisce alcuni dati
INSERT pippo.tabella1 DEFAULT VALUES
INSERT pippo.tabella1 DEFAULT VALUES
INSERT pippo.tabella1 DEFAULT VALUES
INSERT pippo.tabella1 DEFAULT VALUES
INSERT pippo.tabella1 DEFAULT VALUES
GO

-- pippo crea una vista che si basa sulla
-- tabella che ha appena creato
CREATE VIEW pippo.vista1
AS
SELECT * FROM pippo.tabella1
GO

-- pippo da' il permesso di selezionare
-- dalla vista a pluto ma non il permesso
-- selezionare dalla tabella referenziata
-- dalla vista
GRANT SELECT ON vista1 TO pluto 
GO

SETUSER
GO
-- impersonifico pluto
SETUSER 'pluto'
GO

-- pluto puo' correttamente selezionare
-- dalla vista di pippo
SELECT * FROM pippo.vista1
GO

-- pluto crea a sua volta una vista che
-- referenzia la vista di pippo
CREATE VIEW pluto.vista2
AS
SELECT * FROM pippo.vista1
GO

-- pluto da' il permesso di selezionare
-- dalla sua nuova vista a paperoga
GRANT SELECT ON pluto.vista2 TO paperoga 
GO

SETUSER
GO
-- impersonifico paperoga
SETUSER 'paperoga'
GO

-- paperoga non puo' selezionare perche'
-- pluto non puo' trasferire i diritti
-- che gli sono stati trasferiti da pippo
SELECT * FROM pluto.vista2
GO

SETUSER
GO
SETUSER 'pippo'
GO

-- anche pippo deve permettere a paperoga
-- di selezionare dalla sua vista...
GRANT SELECT ON vista1 TO paperoga 
GO

SETUSER
GO
SETUSER 'paperoga'
GO
-- ... perche' paperoga possa selezionare
-- dalle vista di pluto
SELECT * FROM pluto.vista2
GO
