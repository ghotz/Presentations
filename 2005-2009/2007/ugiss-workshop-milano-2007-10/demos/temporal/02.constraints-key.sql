--
--
--
USE tempdb
GO

-- Il primo problema e' quello di ovviare al problema della
-- ridondanza e della circonlocuzione ma non abbiamo a disposizone
-- l'operatore PACK.
--
-- Il metodo piu' semplice e' quello di ricordarsi che il vincolo
-- e' equivalente a dire che se due tuple sono uguali tranne che
-- per i valori i1 e i2 dei due intervalli, i1 MERGES i2 deve
-- essere falso e che MERGES e' definito come OVERLAPS OR MEETS.
--
-- Consideriamo la relazione S_STATUS_DURING
SELECT	*
FROM	S_STATUS_DURING
GO

-- Ora possiamo inserire dati ridondanti
INSERT	S_STATUS_DURING VALUES (1, 15, '2007-01-05', '2007-01-08')
GO

-- Chiediamo che stato aveva il fornitore 1 il giorno 4
SELECT	STATUS
FROM	S_STATUS_DURING
WHERE	S# = 1
  AND	'2007-01-04' BETWEEN D_FROM AND D_TO
GO

-- Chiediamo che stato aveva il fornitore 1 il giorno 5
SELECT	STATUS
FROM	S_STATUS_DURING
WHERE	S# = 1
  AND	'2007-01-05' BETWEEN D_FROM AND D_TO
GO

-- Eliminiamo la riga che ha creato il problema
DELETE	S_STATUS_DURING
WHERE	S# = 1
  AND	D_FROM = '2007-01-05'
  AND	D_TO = '2007-01-08'
GO

-- Creiamo un trigger per proteggerci dalla ridondanza
CREATE TRIGGER TG_S_STATUS_DURING_REDUNDANCY
ON S_STATUS_DURING
FOR INSERT, UPDATE
AS
IF EXISTS (
	SELECT	*
	FROM	S_STATUS_DURING AS S1
	WHERE	1 < (
		SELECT	COUNT(S2.S#)
		FROM	S_STATUS_DURING AS S2
		WHERE 	S1.S# = S2.S#
		  AND	S1.STATUS = S2.STATUS
		  AND	S1.D_FROM <= S2.D_TO
		  AND	S2.D_FROM <= S1.D_TO
	       )
)
BEGIN
	ROLLBACK TRANSACTION
	RAISERROR('Errore: ridondanza', 16, 1)
END
GO

-- Ora verifichiamo che non possiamo inserire dati ridondanti
INSERT	S_STATUS_DURING VALUES (1, 15, '2007-01-05', '2007-01-08')
GO

-- Consideriamo ancora la relazione S_STATUS_DURING
SELECT	*
FROM	S_STATUS_DURING
GO

-- Ora possiamo inserire una circonlocuzione (ed una violazione del predicato)
INSERT	S_STATUS_DURING VALUES (1, 15, '2007-01-06', '2007-01-08')
GO

-- Verifichiamo lo stato del fornitore 1
SELECT	STATUS, D_FROM, D_TO
FROM	S_STATUS_DURING
WHERE	S# = 1
GO

-- C'e' una circonlocuzione, ed una violazione del predicato
-- Eliminiamo la riga che ha creato il problema
DELETE	S_STATUS_DURING
WHERE	S# = 1
  AND	D_FROM = '2007-01-06'
  AND	D_TO = '2007-01-08'
GO

-- Creiamo un trigger per proteggerci dal problema
CREATE TRIGGER TG_S_STATUS_DURING_CIRCUMLOCUTION
ON S_STATUS_DURING
FOR INSERT, UPDATE
AS
IF EXISTS (
	SELECT	*
	FROM	S_STATUS_DURING AS S1
	JOIN	S_STATUS_DURING AS S2
	  ON	S1.S# = S2.S#
	WHERE	S1.STATUS = S2.STATUS
	  AND	S2.D_FROM = DATEADD(day, 1, S1.D_TO)
)
BEGIN
	ROLLBACK TRANSACTION
	RAISERROR('Errore: circonlocuzione', 16, 1)
END
GO

-- Ora verifichiamo che non possiamo inserire una circonlocuzione
INSERT	S_STATUS_DURING VALUES (1, 15, '2007-01-06', '2007-01-08')
GO

-- Rimane ancora il problema della contraddizione
-- Consideriamo ancora la relazione S_STATUS_DURING
SELECT	*
FROM	S_STATUS_DURING
GO

-- Ora possiamo inserire una contraddizione (ed una violazione del predicato)
INSERT	S_STATUS_DURING VALUES (1, 25, '2007-01-05', '2007-01-05')
GO

-- Chiediamo che stato aveva il fornitore 1 il giorno 5
SELECT	STATUS
FROM	S_STATUS_DURING
WHERE	S# = 1
  AND	'2007-01-05' BETWEEN D_FROM AND D_TO
GO

-- Eliminiamo la riga che ha creato il problema
DELETE	S_STATUS_DURING
WHERE	S# = 1
  AND	D_FROM = '2007-01-05'
  AND	D_TO = '2007-01-05'
GO

-- Creiamo un trigger per proteggerci dalla contraddizione
CREATE TRIGGER TG_S_STATUS_DURING_CONTRADICTION
ON S_STATUS_DURING
FOR INSERT, UPDATE
AS

IF EXISTS (
	SELECT	*
	FROM	S_STATUS_DURING AS S1
	WHERE	0 < (
		SELECT	COUNT(S2.S#)
		FROM	S_STATUS_DURING AS S2
		WHERE 	S1.S# = S2.S#
		  AND	S1.STATUS <> S2.STATUS
		  AND	S1.D_FROM <= S2.D_TO
		  AND	S2.D_FROM <= S1.D_TO
	       )
)
BEGIN
	ROLLBACK TRANSACTION
	RAISERROR('Errore: contraddizione', 16, 1)
END
GO

-- Ora verifichiamo che non possiamo inserire una contraddizione
INSERT	S_STATUS_DURING VALUES (1, 25, '2007-01-05', '2007-01-05')
GO

-- Possiamo procedere ad aggiungere i rimanenti trigger
-- Nota: per le tabelle con solo attributi chiave, non serve
-- il vincolo per la contraddizione perche' non e' possibile

-- Tabella S_DURING
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
		  AND	S1.D_FROM <= S2.D_TO
		  AND	S2.D_FROM <= S1.D_TO
	       )
)
BEGIN
	ROLLBACK TRANSACTION
	RAISERROR('Errore: ridondanza', 16, 1)
END
GO

CREATE TRIGGER TG_S_DURING_CIRCUMLOCUTION
ON S_DURING
FOR INSERT, UPDATE
AS
IF EXISTS (
	SELECT	*
	FROM	S_DURING AS S1
	JOIN	S_DURING AS S2
	  ON	S1.S# = S2.S#
	WHERE	S2.D_FROM = DATEADD(day, 1, S1.D_TO)
)
BEGIN
	ROLLBACK TRANSACTION
	RAISERROR('Errore: circonlocuzione', 16, 1)
END
GO

-- test ridondanza
INSERT	S_DURING VALUES (2, '2007-01-04', '2007-01-04')
GO
-- test circonlocuzione
INSERT	S_DURING VALUES (2, '2007-01-05', '2007-01-05')
GO

-- Tabella SP_DURING
CREATE TRIGGER TG_SP_DURING_REDUNDANCY
ON SP_DURING
FOR INSERT, UPDATE
AS
IF EXISTS (
	SELECT	*
	FROM	SP_DURING AS S1
	WHERE	1 < (
		SELECT	COUNT(S2.S#)
		FROM	SP_DURING AS S2
		WHERE 	S1.S# = S2.S#
		  AND	S1.P# = S2.P#
		  AND	S1.D_FROM <= S2.D_TO
		  AND	S2.D_FROM <= S1.D_TO
	       )
)
BEGIN
	ROLLBACK TRANSACTION
	RAISERROR('Errore: ridondanza', 16, 1)
END
GO

CREATE TRIGGER TG_SP_DURING_CIRCUMLOCUTION
ON SP_DURING
FOR INSERT, UPDATE
AS
IF EXISTS (
	SELECT	*
	FROM	SP_DURING AS S1
	JOIN	SP_DURING AS S2
	  ON	S1.S# = S2.S#
	  AND	S1.P# = S2.P#
	WHERE	S2.D_FROM = DATEADD(day, 1, S1.D_TO)
)
BEGIN
	ROLLBACK TRANSACTION
	RAISERROR('Errore: circonlocuzione', 16, 1)
END
GO

SELECT	*
FROM	SP_DURING

-- test ridondanza
INSERT	SP_DURING VALUES (2, 1, '2007-01-04', '2007-01-04')
GO
-- test circonlocuzione
INSERT	SP_DURING VALUES (2, 1, '2007-01-05', '2007-01-05')
GO
