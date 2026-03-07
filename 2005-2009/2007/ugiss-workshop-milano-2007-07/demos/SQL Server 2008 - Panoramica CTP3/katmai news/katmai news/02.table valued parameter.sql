USE master
GO

-- Drop the database if it already exists
IF  EXISTS (
	SELECT name 
		FROM sys.databases 
		WHERE name = N'UGISS'
)
DROP DATABASE UGISS
GO

CREATE DATABASE UGISS
GO

USE UGISS
GO

CREATE TABLE Prodotti
(
idRecord smallint primary key identity(1,1),
descrizione varchar(35),
importo decimal(10,2),
dataAggiornamento datetime,
qta smallint
)
go

/* creo un tipo tabella - USER DEFINED TABLE */
create type productType as table
(
descrizione varchar(35),
importo decimal(10,2)
)
go

/* procedura che riceve i dati da parametro tabella */
create procedure dbo.up_insertProdotti
(
@productT productType READONLY
)
as
set nocount on

	insert Prodotti (descrizione, importo, dataAggiornamento, qta)
	select descrizione, importo, getdate(), 0 from @productT

set nocount off
go

/* TEST */
declare @productT as productType
insert @productT
select 'aaaa',1 union 
select 'bbbb',2 union
select 'cccc',3 union
select 'dddd',4 

exec dbo.up_insertProdotti @productT

select * from prodotti
