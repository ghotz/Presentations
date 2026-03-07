------------------------------------------------------------------------
-- Script:		01.temporal-application-time
-- Copyright:	2016 Gianluca Hotz
-- License:		MIT License
-- Credits:		C.J.Date, Itzik Ben-Gan, Dejan Sarka
------------------------------------------------------------------------
USE master;
GO

--
-- Create test database
--
IF EXISTS(SELECT * FROM sys.databases WHERE name = 'TemporalDB')
BEGIN
	ALTER DATABASE TemporalDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DROP DATABASE TemporalDB;
END
CREATE DATABASE TemporalDB;
GO

USE TemporalDB;
GO

--
-- DEMO 01
--
-- Tabella che si riferisce alla relazione
-- S_DURING {S#, NAME, CITY, DURING} KEY {S#, DURING}
--
-- Predicato: il fornitore identificato da <S#>, con nome <SNAME>,
-- con sede nella città <CITY>, ha avuto un contratto in essere
-- dal giorno di inizio dell'intervallo <DURING> al giorno di
-- fine dell'intervallo <DURING> (e non nei giorni immediatamente
-- prima e dopo l'intervallo <DURING>)
--
-- Incontriamo subito il primo problema non avendo a disposizione
-- un tipo dato intervallo, sostituiamo l'attributo con due
-- attributi che identificano l'inizio e la fine dell'intervallo.
--
-- La nuova relazione diventa
-- S_DURING {S#, NAME, CITY, D_FROM, D_TO} KEY {S#, D_FROM, D_TO}
--
-- Predicato: il fornitore <S#>, con nome <SNAME>, con sede nella
-- città <CITY>, ha avuto un contratto in essere dal giorno <D_FROM>
-- (e non dal giorno precedente) al giorno <D_TO> (e non al giorno
-- successivo).
--
IF OBJECT_ID('S_DURING', 'U') IS NOT NULL
	DROP TABLE S_DURING;
GO

CREATE TABLE S_DURING (
	S#		int		NOT NULL
,	NAME	varchar(20)	NOT NULL
,	CITY	varchar(20)	NOT NULL
,	D_FROM	datetime	NOT NULL
,	D_TO	datetime	NOT NULL
);
GO

--
-- A prima vista la tabella sembra corretta, in realtà dobbiamo creare
-- un vincolo per controllare che la data di fine sia maggiore o uguale
-- alla data di inizio. Se avessimo avuto un tipo dato "intervallo"
-- non saremmo costretti a ripetere questo vincolo per tutte le tabelle
-- perché potrebbe farebbe parte della definizione del tipo stesso.
--
ALTER TABLE S_DURING
ADD CONSTRAINT	CK_S_DURING_D_TO_EQ_GT_D_FROM
CHECK	(D_TO >= D_FROM);
GO

--
-- Il primo problema è quello di ovviare ai problema della
-- ridondanza (duplicazione).
--
-- Normalmente la chiave primaria ci protegge da questo tipo di
-- problemi; ma in questo caso quale sarebbe la chiave primaria?
--
-- Intanto possiamo identificare 2 chiavi candidate per questa
-- tabella e possiamo sceglierne una come primaria.
--
ALTER TABLE S_DURING
ADD CONSTRAINT	PK_S_DURING
	PRIMARY KEY	(S#, D_FROM);
GO

ALTER TABLE S_DURING
ADD CONSTRAINT	AK_S_DURING
	UNIQUE		(S#, D_TO);
GO

-- inseriamo alcuni dati di prova
SET NOCOUNT ON;
INSERT	S_DURING VALUES (1, 'Gianluca',	'Varese',	'2010-01-04', '2010-01-10');
INSERT	S_DURING VALUES (2, 'Davide',	'Milano',	'2010-01-02', '2010-01-04');
INSERT	S_DURING VALUES (2, 'Davide',	'Milano',	'2010-01-07', '2010-01-10');
INSERT	S_DURING VALUES (3, 'Andrea',	'Brescia',	'2010-01-03', '2010-01-10');
INSERT	S_DURING VALUES (4, 'Francesco', 'Milano',	'2010-01-04', '2010-01-10');
INSERT	S_DURING VALUES (5, 'Gilberto',	'Lodi',		'2010-01-02', '2010-01-10');
SET NOCOUNT OFF;
GO

-- Ci sono alcuni problemi con questo approccio.
--
-- Il primo è che le chiavi si sovrappongono violando
-- così la forma normale di Boyce-Codd.
--
-- Il secondo, più importante, è che queste due chiavi
-- ci proteggono solo dal caso particolare in cui la duplicazione,
-- o la contraddizione, sia per lo stesso preciso intervallo.
--
-- Consideriamo la relazione S_STATUS_DURING
--SELECT	*
--FROM	S_DURING;
--GO

-- Ora possiamo inserire dati ridondanti
INSERT	S_DURING
VALUES (1, 'Gianluca', 'Varese', '2010-01-05', '2010-01-08');
GO

-- Chiediamo la città del fornitore 1 il giorno 4
SELECT	CITY
FROM	S_DURING
WHERE	S# = 1
  AND	'2010-01-04' BETWEEN D_FROM AND D_TO;
GO

-- Chiediamo la città del fornitore 1 il giorno 5
SELECT	CITY
FROM	S_DURING
WHERE	S# = 1
  AND	'2010-01-05' BETWEEN D_FROM AND D_TO;
GO

-- Eliminiamo la riga che ha creato il problema
DELETE	S_DURING
WHERE	S# = 1
  AND	D_FROM = '2010-01-05'
  AND	D_TO = '2010-01-08';
GO

--
-- Possiamo implementare il vincolo tramite un trigger
-- verificando che per chiave non sia possibile avere
-- valori di attributi uguali per intervalli che si
-- sovrappongono (i1 OVERLAPS i2)
--
CREATE TRIGGER TG_S_DURING_REDUNDANCY
ON S_DURING
FOR INSERT, UPDATE
AS
	IF EXISTS (
		SELECT	*
		FROM	S_DURING AS S1
		WHERE	1 < (
			SELECT	COUNT(S2.S#)
			FROM	S_DURING AS S2
			WHERE 	S1.S# = S2.S#
			  AND	S1.NAME = S2.NAME
			  AND	S1.CITY = S2.CITY
			  AND	S1.D_FROM <= S2.D_TO
			  AND	S2.D_FROM <= S1.D_TO
			   )
	)
	BEGIN
		ROLLBACK TRANSACTION;
		RAISERROR('Errore: ridondanza', 16, 1);
	END
GO

-- Verifichiamo di no poter inserire dati ridondanti
INSERT	S_DURING
VALUES (1, 'Gianluca', 'Varese', '2010-01-05', '2010-01-08');
GO

--
-- Il secondo problema è quello della contraddizione che al
-- momento è posssibile, come si può facilmente verificare
-- con questo inserimento:
--
INSERT	S_DURING
VALUES (1, 'Gianluca', 'Milano', '2010-01-05', '2010-01-08');
GO

-- Chiediamo la città del fornitore 1 il giorno 5
SELECT	CITY
FROM	S_DURING
WHERE	S# = 1
  AND	'2010-01-05' BETWEEN D_FROM AND D_TO;
GO

-- Eliminiamo la riga che ha creato il problema
DELETE	S_DURING
WHERE	S# = 1
  AND	D_FROM = '2010-01-05'
  AND	D_TO = '2010-01-08';
GO

--
-- Anche in questo caso possiamo procedere con la definizione
-- di un trigger simile al precedente. Verificando che per chiave
-- non sia possibile avere valori di attributi differenti per
-- intervalli che si sovrappongono (i1 OVERLAPS i2)
--
CREATE TRIGGER TG_S_DURING_CONTRADICTION
ON S_DURING
FOR INSERT, UPDATE
AS
	IF EXISTS (
		SELECT	*
		FROM	S_DURING AS S1
		WHERE	0 < (
			SELECT	COUNT(S2.S#)
			FROM	S_DURING AS S2
			WHERE 	S1.S# = S2.S#
			  AND	(
						S1.NAME <> S2.NAME
					 OR S1.CITY <> S2.CITY
					)
			  AND	S1.D_FROM <= S2.D_TO
			  AND	S2.D_FROM <= S1.D_TO
			   )
	)
	BEGIN
		ROLLBACK TRANSACTION;
		RAISERROR('Errore: contraddizione', 16, 1);
	END
GO

-- Verifichiamo che non possiamo inserire dati contraddittori
INSERT	S_DURING
VALUES (1, 'Gianluca', 'Milano', '2010-01-05', '2010-01-08');
GO

--
-- Nota bene: se non si vuole distinguere tra duplicazione
-- e contraddizione, allora è sufficiente verificare che per chiave
-- non si abbiano intervalli sovrapposti (i1 OVERLAPS i2)
DROP TRIGGER TG_S_DURING_REDUNDANCY;
DROP TRIGGER TG_S_DURING_CONTRADICTION;
GO

CREATE TRIGGER TG_S_DURING_REDUNDANCY_CONTRADICTION
ON S_DURING
FOR INSERT, UPDATE
AS
	IF EXISTS (
		SELECT	*
		FROM	S_DURING AS S1
		WHERE	1 < (
			SELECT	COUNT(S2.S#)
			FROM	S_DURING AS S2
			WHERE 	S1.S# = S2.S#
			  AND	S1.D_FROM <= S2.D_TO
			  AND	S2.D_FROM <= S1.D_TO
			   )
	)
	BEGIN
		ROLLBACK TRANSACTION;
		RAISERROR('Errore: ridondanza o contraddizione', 16, 1);
	END
GO

-- Verifichiamo che non possiamo inserire dati ridondanti
INSERT	S_DURING
VALUES (1, 'Gianluca', 'Varese', '2010-01-05', '2010-01-08');
GO
-- Verifichiamo che non possiamo inserire dati contraddittori
INSERT	S_DURING
VALUES (1, 'Gianluca', 'Milano', '2010-01-05', '2010-01-08');
GO

--
-- Un terzo problema è quello della circonlocuzione cioé dico
-- una cosa con molteplici proposizioni quando potrei dirla
-- con una sola (nota che in questo caso è una violazione del
-- predicato per come l'abbiamo definito).
--
-- Inseriamo ad esempio:
INSERT	S_DURING
VALUES (2, 'Davide', 'Milano', '2010-01-05', '2010-01-06');
GO

-- Chiediamo che stato aveva il fornitore 1 il giorno 5
-- Verifichiamo quando il fornitore 2 ha un contratto in essere
SELECT	S#, D_FROM, D_TO
FROM	S_DURING
WHERE	S# = 2;
GO

--
-- Questi tre fatti si possono esprimere in maniera
-- più compatta con la proposizione instanziata dal
-- predicato con i seguenti valori:
-- {2, Davide, Milano, 2010-01-02, 2010-01-10}
--
DELETE	S_DURING
WHERE	S# = 2
  AND	D_FROM = '2010-01-05'
  AND	D_TO = '2010-01-06'
GO

--
-- Anche in questo caso possiamo crare il vincolo tramite
-- un trigger che non permetta la circonlocuzione
-- (i1 MEETS i2)
--
CREATE TRIGGER TG_S_DURING_CIRCUMLOCUTION
ON S_DURING
FOR INSERT, UPDATE
AS
	IF EXISTS (
		SELECT	*
		FROM	S_DURING AS S1
		JOIN	S_DURING AS S2
		  ON	S1.S# = S2.S#
		WHERE	S1.NAME = S2.NAME
		  AND	S1.CITY = S2.CITY
		  AND	S2.D_FROM = DATEADD(day, 1, S1.D_TO)
	)
	BEGIN
		ROLLBACK TRANSACTION;
		RAISERROR('Errore: circonlocuzione', 16, 1);
	END
GO

-- Verifichiamo che non possiamo inserire circonlocuzioni
INSERT	S_DURING
VALUES (2, 'Davide', 'Milano', '2010-01-05', '2010-01-06');
GO

--
-- DEMO 02
--
-- Supponiamo di volere fare una JOIN temporale, prima
-- creiamo la tabella per la relazione molti-a-molti
--

--
-- Tabella che si riferisce alla relazione
-- SP_DURING {S#, P#, DURING} KEY {S#, P#, DURING}
--
-- Predicato: il fornitore <S#> è stato in grado di fornire il
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
-- Predicato: il fornitore <S#> è stato in grado di fornire il
-- prodotto <P#> dal giorno <D_FROM> (e non dal giorno precedente)
-- al giorno <D_TO> (e non al giorno successivo).
--
IF OBJECT_ID('SP_DURING', 'U') IS NOT NULL
	DROP TABLE SP_DURING;
GO

CREATE TABLE SP_DURING (
	S#		int		NOT NULL
,	P#		int		NOT NULL
,	D_FROM		datetime	NOT NULL
,	D_TO		datetime	NOT NULL

,	CONSTRAINT	PK_SP_DURING
	PRIMARY KEY	(S#, P#, D_FROM)

,	CONSTRAINT	AK_SP_DURING
	UNIQUE		(S#, P#, D_TO)

,	CONSTRAINT	CK_SP_DURING_D_TO_EQ_GT_D_FROM
	CHECK		(D_TO >= D_FROM)
);
GO

-- Inseriamo i valori come nell'esempio della slide
TRUNCATE TABLE S_DURING;
GO

SET NOCOUNT ON;
INSERT	S_DURING VALUES (2, 'Davide', 'Milano',		'2010-01-02', '2010-01-04');
INSERT	S_DURING VALUES (2, 'Davide', 'Milano',		'2010-01-07', '2010-01-10');
INSERT	S_DURING VALUES (4, 'Francesco', 'Milano',	'2010-01-04', '2010-01-10');

INSERT	SP_DURING VALUES (2, 1, '2010-01-02', '2010-01-04');
INSERT	SP_DURING VALUES (2, 2, '2010-01-03', '2010-01-04');
INSERT	SP_DURING VALUES (4, 4, '2010-01-02', '2010-01-04');
SET NOCOUNT OFF;
GO

--
-- Vediamo ora come effettuare un'operazione di PACK/UNPACK
--

--
-- Per prima cosa, non avendo un generatore di relazioni,
-- dobbiamo crare un calendario che contenga tutti gli
-- elementi che ci servono per le interrogazioni
--

-- Helper function per generare relazione numeri interi
IF OBJECT_ID('fn_Nums', 'IF') IS NOT NULL
	DROP FUNCTION fn_Nums;
GO

CREATE FUNCTION fn_Nums(@m as bigint)
RETURNS TABLE
AS
RETURN
WITH
	t0 as (select n = 1 union all select n = 1),
	t1 as (select n = 1 from t0 as a, t0 as b),
	t2 as (select n = 1 from t1 as a, t1 as b),
	t3 as (select n = 1 from t2 as a, t2 as b),
	t4 as (select n = 1 from t3 as a, t3 as b),
	t5 as (select n = 1 from t4 as a, t4 as b),
	result as (select ROW_NUMBER() over (order by n) as n from t5)
	select n from result where n <= @m;
GO

IF OBJECT_ID('CALENDAR', 'U') IS NOT NULL
	DROP TABLE CALENDAR;
GO

CREATE TABLE CALENDAR (
	PT_DATE	date	NOT NULL PRIMARY KEY
,	n		int		NOT NULL

,	CONSTRAINT	ak_CALENDAR
	UNIQUE		(n)
);

INSERT CALENDAR
SELECT	DATEADD(dd, n, CAST('20100101' as date)), n
FROM	fn_Nums(DATEDIFF(dd, '20100101', '20101231'));
GO

-- riferimento
SELECT * FROM S_DURING WHERE S# = 2;
GO

-- Per simulare l'operazione di UNPACK basta effettuare
-- un'operazione di JOIN con il calendario.
SELECT	S.S#
,		S.NAME
,		S.CITY
,		C.PT_DATE AS D_FROM
,		C.PT_DATE AS D_TO
FROM	S_DURING AS S
JOIN	CALENDAR AS C
  ON	C.PT_DATE BETWEEN S.D_FROM AND S.D_TO
 WHERE	S.S# = 2;
 GO

 -- Per simulare l'operazione di PACK sfruttiamo l'equivalenza
 -- PACK() = PACK(UNPACK) quindi tramite alcune CTE prima
 -- generiamo la vesione UNPACKed e poi facciamo il PACK
 -- vero e proprio

-- eseguire solo per vedere step intermedi
--
WITH Unpack_S_DURING AS
(
		SELECT	S.S#
	,		S.NAME
	,		S.CITY
	,		C.PT_DATE AS D_FROM
	,		C.PT_DATE AS D_TO
	,		C.PT_DATE
	,		C.n				--,	CAST(CAST(C.PT_DATE as datetime) as int) AS n
	FROM	S_DURING AS S
	JOIN	CALENDAR AS C
		ON	C.PT_DATE BETWEEN S.D_FROM AND S.D_TO
)
,	GroupingFactor AS
(
	SELECT	S#
	,		NAME
	,		CITY
	,		D_FROM
	,		D_TO
	,		n
	,		DENSE_RANK() OVER (PARTITION BY S# ORDER BY n) AS dr
	,		n - DENSE_RANK() OVER (PARTITION BY S# ORDER BY n) AS gf
	FROM	Unpack_S_DURING
)
SELECT * FROM GroupingFactor
ORDER BY 1, 6, 7, 8;
--	ORDER BY 4, 1;
GO

-- riferimento
SELECT * FROM S_DURING WHERE S# = 2;
GO

-- query finale PACK
WITH Unpack_S_DURING AS
(
	SELECT	S.S#
	,		S.NAME
	,		S.CITY
	,		C.PT_DATE
	,		C.n
	FROM	S_DURING AS S
	JOIN	CALENDAR AS C
	  ON	C.PT_DATE BETWEEN S.D_FROM AND S.D_TO
)
,	GroupingFactor AS
(
	SELECT	S#
	,		NAME
	,		CITY
	,		PT_DATE AS D_FROM
	,		PT_DATE AS D_TO
	,		n - DENSE_RANK() OVER (PARTITION BY S# ORDER BY n) AS gf
	FROM	Unpack_S_DURING
)
SELECT	S#
,		MAX(NAME) AS NAME
,		MAX(CITY) AS CITY
,		MIN(D_FROM) AS D_FROM
,		MAX(D_TO)	AS D_TO
FROM	GroupingFactor
WHERE	S# = 2
GROUP BY S#, gf
ORDER BY S#, D_FROM;
GO

--
-- Mettiamo ora tutto insieme per effettuare la Join
--
WITH Unpack_S_DURING AS
(
	SELECT	S.S#
	,		C.PT_DATE
	,		C.n
	FROM	S_DURING AS S
	JOIN	CALENDAR AS C
	  ON	C.PT_DATE BETWEEN S.D_FROM AND S.D_TO
)
,	Unpack_SP_DURING AS
(
	SELECT	SP.S#
	,		SP.P#
	,		C.PT_DATE
	,		C.n
	FROM	SP_DURING AS SP
	JOIN	CALENDAR AS C
	  ON	C.PT_DATE BETWEEN SP.D_FROM AND SP.D_TO
)
,	S_DURING_Joined_SP_DURING AS
(
	SELECT	S.S#
	,		SP.P#
	,		S.PT_DATE
	,		S.n
	FROM	Unpack_S_DURING  AS S
	JOIN	Unpack_SP_DURING AS SP
	  ON	S.S# = SP.S#
	 AND	S.PT_DATE = SP.PT_DATE
)
,	GroupingFactor AS
(
	SELECT	J.S#
	,		J.P#
	,		J.PT_DATE AS D_FROM
	,		J.PT_DATE AS D_TO
	,		J.n - DENSE_RANK() OVER (PARTITION BY J.S#, J.P# ORDER BY J.n) AS gf
	FROM	S_DURING_Joined_SP_DURING AS J
)
SELECT	S#
,		P#
,		MIN(D_FROM) AS D_FROM
,		MAX(D_TO)	AS D_TO
FROM	GroupingFactor
--WHERE	S# = 2
GROUP BY S#, P#, gf
ORDER BY S#, D_FROM;
GO

