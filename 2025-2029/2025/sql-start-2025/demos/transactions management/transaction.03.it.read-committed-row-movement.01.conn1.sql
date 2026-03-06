------------------------------------------------------------------------
-- Copyright:   2018 Gianluca Hotz
-- License:     MIT License
--              Permission is hereby granted, free of charge, to any
--              person obtaining a copy of this software and associated
--              documentation files (the "Software"), to deal in the
--              Software without restriction, including without
--              limitation the rights to use, copy, modify, merge,
--              publish, distribute, sublicense, and/or sell copies of
--              the Software, and to permit persons to whom the
--              Software is furnished to do so, subject to the
--              following conditions:
--              
--              The above copyright notice and this permission notice
--              shall be included in all copies or substantial portions
--              of the Software.
--              
--              THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
--              ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
--              LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
--              FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
--              EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
--              FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
--              AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--              OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
--              OTHER DEALINGS IN THE SOFTWARE.
-- Credits:     Davide Mauri
------------------------------------------------------------------------
USE tempdb;
GO

IF OBJECT_ID('t', 'U') IS NOT NULL
  DROP TABLE t;
GO

CREATE TABLE t (a int PRIMARY KEY, b int);
INSERT t VALUES (1, 1);
INSERT t VALUES (2, 2);
INSERT t VALUES (3, 3);
GO

BEGIN TRANSACTION

	UPDATE t
	SET    b = 2
	WHERE  a = 2;

	-- switch connessione 2, selezione e tornare

	UPDATE t
	SET    a = 0
	WHERE  a = 3;

	-- verificare i dati dopo update
	SELECT * FROM t;

COMMIT TRANSACTION
-- switch connessione 2 e selezione

/*
che cosa è successo?

tabella iniziale: 
a | b
-----
1 | 1
2 | 2
3 | 3

1) connessione 1 fa update su riga 2 (imposta solo il lock NON fa modifiche ai dati)
2) connessione 2 inizia a leggere
	- legge riga 1 (non ha lock)
	- si ferma a riga 2 in attesa che il lock venga rilasciato
3) connessione 1 aggiorna riga 3 impostando a=0 
	(quindi questa riga, avendo la tabella una PK su a, viene portata in testa alla datapage)
4) connessione 2 non ha più lock e continua a leggere:
	- legge riga 2
	- non ha altre righe da leggere!

Risultato per connessione 1:
a | b
-----
0 | 3
1 | 1
2 | 2

Risultato per connessione 2:
a | b
-----
1 | 1
2 | 2

*/


------------------------------------------------------------------------
-- Allo stesso modo potrei leggere piu' volte una stessa riga
------------------------------------------------------------------------
IF OBJECT_ID('t', 'U') IS NOT NULL
  DROP TABLE t;
GO

CREATE TABLE t (a int PRIMARY KEY, b int);
INSERT t VALUES (1, 1);
INSERT t VALUES (2, 2);
INSERT t VALUES (3, 3);
GO

BEGIN TRANSACTION

	UPDATE t
	SET    b = 2
	WHERE  a = 2;

	-- switch connessione 2, selezione e tornare

	UPDATE t
	SET    a = 4
	WHERE  a = 1;

	-- verificare i dati dopo update
	SELECT * FROM t;

COMMIT TRANSACTION
-- switch connessione 2 e selezione

