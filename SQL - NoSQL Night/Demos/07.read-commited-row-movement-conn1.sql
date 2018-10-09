use tempDB
go

IF OBJECT_ID('dbo.t', 'U') IS NOT NULL
  DROP TABLE dbo.t
GO

create table t (a int primary key, b int)
insert t values (1, 1)
insert t values (2, 2)
insert t values (3, 3)

begin tran
update t set b = 2 where a = 2
--> vado su connessione 2

update t set a = 0 where a = 3

select * from t
commit tran



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


/*
ALLO STESSO MODO POTREI LEGGERE PIU' VOLTE UNA STESSA RIGA
*/
use tempDB
go

IF OBJECT_ID('dbo.t', 'U') IS NOT NULL
  DROP TABLE dbo.t
GO

create table t (a int primary key, b int)
insert t values (1, 1)
insert t values (2, 2)
insert t values (3, 3)

begin tran
update t set b = 2 where a = 2
--> vado su connessione 2

update t set a = 4 where a = 1

select * from t
commit tran
