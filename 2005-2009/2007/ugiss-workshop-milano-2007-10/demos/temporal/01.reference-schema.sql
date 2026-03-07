--
--
--
USE tempdb
GO

--
-- Tabella che si riferisce alla relazione
-- S_SINCE {S#, S#_SINCE, STATUS, STATUS_SINCE} KEY {S#}
--
-- Predicato: il fornitore <S#> ha un contratto in essere dalla
-- data <S#_SINCE> (e non dal giorno precedente) ed ha stato <STATUS>
-- dalla data <STATUS_SINCE> (e non dal giorno precedente).
--
IF OBJECT_ID('S_SINCE') IS NOT NULL
	DROP TABLE S_SINCE
GO

CREATE TABLE S_SINCE (
	S#		int		NOT NULL
,	S#_SINCE	datetime	NOT NULL
,	STATUS		int		NOT NULL
,	STATUS_SINCE	datetime	NOT NULL

,	CONSTRAINT	PK_S_SINCE
	PRIMARY KEY	(S#)
)
GO

SET NOCOUNT ON
INSERT	S_SINCE VALUES (1, '2007-01-04', 20, '2007-01-06')
INSERT	S_SINCE VALUES (2, '2007-01-07', 10, '2007-01-07')
INSERT	S_SINCE VALUES (3, '2007-01-03', 30, '2007-01-03')
INSERT	S_SINCE VALUES (4, '2007-01-04', 20, '2007-01-08')
INSERT	S_SINCE VALUES (5, '2007-01-02', 30, '2007-01-02')
SET NOCOUNT OFF
GO

--
-- Tabella che si riferisce alla relazione
-- SP_SINCE {S#, P#, SINCE} KEY {S#, P#}
--
-- Predicato: il fornitore <S#> e' in grado di fornire il prodotto
-- <P#> dalla data <SINCE> (e non dal giorno precedente)
--
IF OBJECT_ID('SP_SINCE') IS NOT NULL
	DROP TABLE SP_SINCE
GO

CREATE TABLE SP_SINCE (
	S#		int		NOT NULL
,	P#		int		NOT NULL
,	SINCE		datetime	NOT NULL

,	CONSTRAINT	PK_SP_SINCE
	PRIMARY KEY	(S#, P#)
)
GO

SET NOCOUNT ON
INSERT	SP_SINCE VALUES (1, 1, '2007-01-04')
INSERT	SP_SINCE VALUES (1, 2, '2007-01-05')
INSERT	SP_SINCE VALUES (1, 3, '2007-01-09')
INSERT	SP_SINCE VALUES (1, 4, '2007-01-05')
INSERT	SP_SINCE VALUES (1, 5, '2007-01-04')
INSERT	SP_SINCE VALUES (1, 6, '2007-01-06')
INSERT	SP_SINCE VALUES (2, 1, '2007-01-08')
INSERT	SP_SINCE VALUES (2, 2, '2007-01-09')
INSERT	SP_SINCE VALUES (3, 2, '2007-01-08')
INSERT	SP_SINCE VALUES (4, 5, '2007-01-05')
SET NOCOUNT OFF
GO

--
-- Tabella che si riferisce alla relazione
-- S_DURING {S#, DURING} KEY {S#, DURING}
--
-- Predicato: il fornitore <S#> ha avuto un contratto in essere
-- dal giorno di inizio dell'intervallo <DURING> al giorno di
-- fine dell'intervallo <DURING> (e non nei giorni immediatamente
-- prima e dopo l'intervallo <DURING>)
--
-- Incontriamo subito il primo problema non avendo a disposizione
-- un tipo dato intervallo, sostituiamo l'attributo con due
-- attributi che identificano l'inizio e la fine dell'intervallo.
--
-- La nuova relazione diventa
-- S_DURING {S#, D_FROM, D_TO} KEY {S#, D_FROM, D_TO}
--
-- Predicato: il fornitore <S#> ha avuto un contratto in essere
-- dal giorno <D_FROM> (e non dal giorno precedente) al giorno <D_TO>
-- (e non al giorno successivo).
--
IF OBJECT_ID('S_DURING') IS NOT NULL
	DROP TABLE S_DURING
GO

CREATE TABLE S_DURING (
	S#		int		NOT NULL
,	D_FROM		datetime	NOT NULL
,	D_TO		datetime	NOT NULL

,	CONSTRAINT	PK_S_DURING
	PRIMARY KEY	(S#, D_FROM, D_TO)
)
GO

--
-- A prima vista la tabella sembra corretta, in realta' abbiamo assunto
-- che il tipo dato intervallo controllasse automaticamente che la data
-- di fine fosse maggiore o uguale alla data di inizio.
--
-- Esempio:	INSERT	S_DURING VALUES (1, '2007-01-05', '2007-01-04')
--
-- Dobbiamo quindi creare un vincolo che impedisca tale problema.
--
ALTER TABLE S_DURING
ADD CONSTRAINT	CK_S_DURING_D_TO_EQ_GT_D_FROM
CHECK	(D_TO >= D_FROM)
GO

SET NOCOUNT ON
INSERT	S_DURING VALUES (2, '2007-01-02', '2007-01-04')
INSERT	S_DURING VALUES (6, '2007-01-03', '2007-01-05')
SET NOCOUNT OFF
GO

--
-- Tabella che si riferisce alla relazione
-- S_STATUS_DURING {S#, STATUS, DURING} KEY {S#, DURING}
--
-- Predicato: il fornitore <S#> ha avuto stato <STATUS>
-- dal giorno di inizio dell'intervallo <DURING> al giorno di
-- fine dell'intervallo <DURING> (e non nei giorni immediatamente
-- prima e dopo l'intervallo <DURING>)
--
-- Incontriamo lo stesso problema visto precedentemente non avendo
-- a disposizione un tipo dato intervallo. Sostituiamo l'attributo
-- con due attributi che identificano l'inizio e la fine dell'intervallo.
--
-- La nuova relazione diventa
-- S_STATUS_DURING {S#, STATUS, D_FROM, D_TO} KEY {S#, D_FROM, D_TO}
--
-- Predicato: il fornitore <S#> ha avuto stato <STATUS>
-- dal giorno <D_FROM> (e non dal giorno precedente) al giorno <D_TO>
-- (e non al giorno successivo).
--
IF OBJECT_ID('S_STATUS_DURING') IS NOT NULL
	DROP TABLE S_STATUS_DURING
GO

CREATE TABLE S_STATUS_DURING (
	S#		int		NOT NULL
,	STATUS		int		NOT NULL
,	D_FROM		datetime	NOT NULL
,	D_TO		datetime	NOT NULL

,	CONSTRAINT	PK_S_STATUS_DURING
	PRIMARY KEY	(S#, D_FROM, D_TO)
)
GO

--
-- Anche in questo caso, non avendo a disposizione un controllo
-- automatico perche' la data di fine sia maggiore o uguale alla
-- data di inizio, dobbiamo creare un vincolo.
--
ALTER TABLE S_STATUS_DURING
ADD CONSTRAINT	CK_S_STATUS_DURING_D_TO_EQ_GT_D_FROM
CHECK	(D_TO >= D_FROM)
GO

SET NOCOUNT ON
INSERT	S_STATUS_DURING VALUES (1, 15, '2007-01-04', '2007-01-05')
INSERT	S_STATUS_DURING VALUES (2,  5, '2007-01-02', '2007-01-02')
INSERT	S_STATUS_DURING VALUES (2, 10, '2007-01-03', '2007-01-04')
INSERT	S_STATUS_DURING VALUES (4, 10, '2007-01-04', '2007-01-04')
INSERT	S_STATUS_DURING VALUES (4, 25, '2007-01-05', '2007-01-07')
INSERT	S_STATUS_DURING VALUES (6,  5, '2007-01-03', '2007-01-04')
INSERT	S_STATUS_DURING VALUES (6,  7, '2007-01-05', '2007-01-05')
SET NOCOUNT OFF
GO

--
-- Tabella che si riferisce alla relazione
-- SP_DURING {S#, P#, DURING} KEY {S#, P#, DURING}
--
-- Predicato: il fornitore <S#> e' stato in grado di fornire il
-- prodotto <P#> dal giorno di inizio dell'intervallo <DURING> al
-- giorno di fine dell'intervallo <DURING> (e non nei giorni
-- immediatamente prima e dopo l'intervallo <DURING>)
--
-- Incontriamo lo stesso problema visto precedentemente non avendo
-- a disposizione un tipo dato intervallo. Sostituiamo l'attributo
-- con due attributi che identificano l'inizio e la fine dell'intervallo.
--
-- La nuova relazione diventa
-- SP_DURING {S#, P#, D_FROM, D_TO} KEY {S#, P#, D_FROM, D_TO}
--
-- Predicato: il fornitore <S#> e' stato in grado di fornire il
-- prodotto <P#> dal giorno <D_FROM> (e non dal giorno precedente)
-- al giorno <D_TO> (e non al giorno successivo).
--
IF OBJECT_ID('SP_DURING') IS NOT NULL
	DROP TABLE SP_DURING
GO

CREATE TABLE SP_DURING (
	S#		int		NOT NULL
,	P#		int		NOT NULL
,	D_FROM		datetime	NOT NULL
,	D_TO		datetime	NOT NULL

,	CONSTRAINT	PK_SP_DURING
	PRIMARY KEY	(S#, P#, D_FROM, D_TO)
)
GO

--
-- Anche in questo caso, non avendo a disposizione un controllo
-- automatico perche' la data di fine sia maggiore o uguale alla
-- data di inizio, dobbiamo creare un vincolo.
--
ALTER TABLE SP_DURING
ADD CONSTRAINT	CK_SP_DURING_D_TO_EQ_GT_D_FROM
CHECK	(D_TO >= D_FROM)
GO

SET NOCOUNT ON
INSERT	SP_DURING VALUES (2, 1, '2007-01-02', '2007-01-04')
INSERT	SP_DURING VALUES (2, 2, '2007-01-03', '2007-01-03')
INSERT	SP_DURING VALUES (3, 5, '2007-01-05', '2007-01-07')
INSERT	SP_DURING VALUES (4, 2, '2007-01-06', '2007-01-09')
INSERT	SP_DURING VALUES (4, 4, '2007-01-04', '2007-01-08')
INSERT	SP_DURING VALUES (6, 3, '2007-01-03', '2007-01-03')
INSERT	SP_DURING VALUES (6, 3, '2007-01-05', '2007-01-05')
SET NOCOUNT OFF
GO

--
-- Verifichiamo i dati inseriti.
--

-- Dati correnti
SELECT * FROM S_SINCE
SELECT * FROM SP_SINCE
GO

-- Dati storici
SELECT * FROM S_DURING
SELECT * FROM S_STATUS_DURING
SELECT * FROM SP_DURING
GO

--
-- Creiamo delle viste per vedere i valori come nelle slide
--
IF OBJECT_ID('S_SINCE_SLIDE') IS NOT NULL
	DROP VIEW S_SINCE_SLIDE
GO

CREATE VIEW S_SINCE_SLIDE AS
SELECT	'S' + CAST(S# AS varchar(1)) AS S#
,	'd' + RIGHT('0' + CAST(DAY(S#_SINCE) AS varchar(1)), 2) AS S#_SINCE
,	STATUS
,	'd' + RIGHT('0' + CAST(DAY(STATUS_SINCE) AS varchar(1)), 2) AS STATUS_SINCE
FROM	S_SINCE
GO

IF OBJECT_ID('SP_SINCE_SLIDE') IS NOT NULL
	DROP VIEW SP_SINCE_SLIDE
GO

CREATE VIEW SP_SINCE_SLIDE AS
SELECT	'S' + CAST(S# AS varchar(1)) AS S#
,	'P' + CAST(S# AS varchar(1)) AS P#
,	'd' + RIGHT('0' + CAST(DAY(SINCE) AS varchar(1)), 2) AS SINCE
FROM	SP_SINCE
GO

IF OBJECT_ID('S_DURING_SLIDE') IS NOT NULL
	DROP VIEW S_DURING_SLIDE
GO

CREATE VIEW S_DURING_SLIDE AS
SELECT	'S' + CAST(S# AS varchar(1)) AS S#
,	'[d' + RIGHT('0' + CAST(DAY(D_FROM) AS varchar(1)), 2)
	+ ':d' + RIGHT('0' + CAST(DAY(D_TO) AS varchar(1)), 2)
	+ ']' AS DURING
FROM	S_DURING
GO

IF OBJECT_ID('S_STATUS_DURING_SLIDE') IS NOT NULL
	DROP VIEW S_STATUS_DURING_SLIDE
GO

CREATE VIEW S_STATUS_DURING_SLIDE AS
SELECT	'S' + CAST(S# AS varchar(1)) AS S#
,	STATUS
,	'[d' + RIGHT('0' + CAST(DAY(D_FROM) AS varchar(1)), 2)
	+ ':d' + RIGHT('0' + CAST(DAY(D_TO) AS varchar(1)), 2)
	+ ']' AS DURING
FROM	S_STATUS_DURING
GO

IF OBJECT_ID('SP_DURING_SLIDE') IS NOT NULL
	DROP VIEW SP_DURING_SLIDE
GO

CREATE VIEW SP_DURING_SLIDE AS
SELECT	'S' + CAST(S# AS varchar(1)) AS S#
,	'P' + CAST(S# AS varchar(1)) AS P#
,	'[d' + RIGHT('0' + CAST(DAY(D_FROM) AS varchar(1)), 2)
	+ ':d' + RIGHT('0' + CAST(DAY(D_TO) AS varchar(1)), 2)
	+ ']' AS DURING
FROM	SP_DURING
GO

-- Dati correnti
SELECT * FROM S_SINCE_SLIDE
SELECT * FROM SP_SINCE_SLIDE
GO

-- Dati storici
SELECT * FROM S_DURING_SLIDE
SELECT * FROM S_STATUS_DURING_SLIDE
SELECT * FROM SP_DURING_SLIDE
GO
