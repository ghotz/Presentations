------------------------------------------------------------------------
-- Script:			vincoli.sql
-- Author:			Gianluca Hotz (Solid Quality Mentors)
-- Copyright:		Attribution-NonCommercial-ShareAlike 2.5
-- Version:			SQL Server 2008
------------------------------------------------------------------------

-- direttiva per cambiare database predefinito
USE master;
GO

--
-- creazione di un nuovo database (lo elimina se esiste già)
--
IF EXISTS(SELECT * FROM sys.databases WHERE name = 'GestioneHotel')
	DROP DATABASE GestioneHotel;
GO

CREATE DATABASE GestioneHotel;
GO

-- direttiva per cambiare database predefinito
USE GestioneHotel;
GO

--
-- Creazione della tabella con i vincoli di colonna per le
-- regole aziendali:
--
-- R1: Numero di prenotazione tra 1 e 100000
-- R2: Numero di stanza tra 1 e 350
-- R3: Tutti gli arrivi e le partenze sono posteriori al 1/10/1980
--
-- Aggiungiamo alcuni DEFAULT non definiti dalle regole
-- aziendali a scopo di illustarne la sintassi.
--
--drop table Prenotazione
CREATE TABLE Prenotazione (

	IDPrenotazione	int			NOT NULL
	CONSTRAINT		DominioIDPrenotazione
	CHECK			(IDPrenotazione BETWEEN 1 AND 100000)

,	NumStanza		smallint	NOT NULL
	CONSTRAINT		DominioNumStanza
	CHECK			(NumStanza BETWEEN 1 AND 350)

,	DataArrivo		date		NOT NULL
	CONSTRAINT		DefaultDataArrivo
	DEFAULT			(GETDATE())
	CONSTRAINT		DominioDataArrivo
	CHECK			(DataArrivo > '19801001')

,	DataPartenza	date		NOT NULL
	CONSTRAINT		DefaultDataPartenza
	DEFAULT			(GETDATE()+1)
	CONSTRAINT		DominioDataPartenza
	CHECK			(DataPartenza > '19801001')
);
GO

--
-- inserimento valori
--
INSERT	Prenotazione
		(IDPrenotazione, NumStanza, DataArrivo, DataPartenza)
VALUES	(99000, 333, '20061029', '20061101'),
		(99001, 275, '20061027', '20061030');
GO

--
-- esempi di valori non accettati
--

-- Numero stanza fuori dai valori di dominio
INSERT	Prenotazione
		(IDPrenotazione, NumStanza, DataArrivo, DataPartenza)
VALUES	(99002, 500, '20061029', '20061101');
GO

-- Data di arrivo fuori dai valori di dominio
INSERT	Prenotazione
		(IDPrenotazione, NumStanza, DataArrivo, DataPartenza)
VALUES	(99002, 300, '19800101', '20061101');
GO

-- 
-- torniamo alla presentazione
-- 

-- 
-- Aggiungiamo un vincolo CHECK per la regola aziendale
--
-- R4: Per tutte le prenotazioni, la data di partenza
--     è posteriore alla data arrivo
-- 
ALTER TABLE Prenotazione
ADD	CONSTRAINT DataPartenzaMaggioreDataArrivo
	CHECK		(DataPartenza > DataArrivo);
GO

--
-- esempio di valore non accettato
-- data partenza coincidente
--
INSERT	Prenotazione
		(IDPrenotazione, NumStanza, DataArrivo, DataPartenza)
VALUES	(99002, 300, '20061029', '20061029');
GO

-- 
-- torniamo alla presentazione
-- 

-- 
-- Aggiungiamo i vincoli PRIMARY KEY e UNIQUE per le regole
-- aziendali
--
-- R5: Le prenotazioni hanno numero prenotazione distinto
-- R6: Per tutte le prenotazioni, la combinazione del
--     numero stanza e della data di arrivo è univoca
-- R7: Per tutte le prenotazioni, la combinazione del
--     numero stanza e della data di partenza è univoca
-- 
ALTER TABLE Prenotazione
ADD CONSTRAINT	pkPrenotazione
	PRIMARY KEY	(IDPrenotazione);

ALTER TABLE Prenotazione
ADD CONSTRAINT	akPrenotazione_01
	UNIQUE	(NumStanza, DataArrivo);

ALTER TABLE Prenotazione
ADD CONSTRAINT	akPrenotazione_02
	UNIQUE	(NumStanza, DataPartenza);
GO

--
-- esempi di valore non accettato
--

-- Numero prenotazione duplicato
INSERT	Prenotazione
		(IDPrenotazione, NumStanza, DataArrivo, DataPartenza)
VALUES	(99001, 275, '20061027', '20061030');
GO

-- stanza prenotata con stessa data di arrivo
INSERT	Prenotazione
		(IDPrenotazione, NumStanza, DataArrivo, DataPartenza)
VALUES	(99003, 275, '20061027', '20061029');
GO

-- 
-- Aggiungiamo il vincolo TRIGGER per la regola aziendale
--
-- R8: Le prenotazioni per la stessa camera non si sovrappongono
--
CREATE TRIGGER tgPrenotazioneNoSovrapposizione
ON Prenotazione
FOR UPDATE, INSERT
AS

	IF EXISTS(
		SELECT	*
		FROM	inserted AS I1
		JOIN	Prenotazione AS P1
		  ON	I1.IDPrenotazione <> P1.IDPrenotazione
		WHERE	I1.NumStanza = P1.NumStanza
		  AND	P1.DataArrivo < I1.DataPartenza
		  AND	P1.DataPartenza > I1.DataArrivo
		)
		BEGIN
			RAISERROR('Violazione della regola R8: Le prenotazioni per la stessa camera non si sovrappongono', 10, 1)
			ROLLBACK TRAN;
		END
GO

--
-- esempi di valore non accettato
--

-- Numero prenotazione duplicato
INSERT	Prenotazione
		(IDPrenotazione, NumStanza, DataArrivo, DataPartenza)
VALUES	(99003, 275, '20061028', '20061031');
GO

--
-- Supponiamo di voler vincolare il numero stanza
-- enumerandone gli elementi, possiamo creare una
-- tabella per le stanze
---
CREATE TABLE Stanza (
	NumStanza	smallint	NOT NULL

,	CONSTRAINT	pkStanza
	PRIMARY	KEY	(NumStanza)
)
GO

--
-- inseriamo i record;
--
SET NOCOUNT ON
DECLARE	@i smallint = 1;
WHILE (@i < 351)
BEGIN
	INSERT Stanza (NumStanza) VALUES (@i);
	SET	@i = @i + 1;
END
SET NOCOUNT OFF;
GO

--
-- creiamo un vincolo di integrita referenziale
--
ALTER TABLE Prenotazione
ADD	CONSTRAINT	fkPrenotazione_Stanza
	FOREIGN KEY	(NumStanza)
	REFERENCES	Stanza(NumStanza)
		ON DELETE NO ACTION
		ON UPDATE CASCADE;
GO

--
-- eliminiamo il vecchio vincolo
--
ALTER TABLE Prenotazione
DROP CONSTRAINT DominioNumStanza;
GO

--
-- verifichiamo che comunque il vincolo di
-- dominio è ora sostituito da quello
-- referenziale
--
INSERT	Prenotazione
		(IDPrenotazione, NumStanza, DataArrivo, DataPartenza)
VALUES	(99003, 351, '20061201', '20061202');
GO

--
-- cerchiamo di eliminare un valore referenziato
--
DELETE	Stanza
WHERE	NumStanza = 275;
GO

--
-- se invece aggiorniamo un valore
--
UPDATE	Stanza
SET		NumStanza = 351
WHERE	NumStanza = 275;
GO

SELECT	* FROM Prenotazione;
GO