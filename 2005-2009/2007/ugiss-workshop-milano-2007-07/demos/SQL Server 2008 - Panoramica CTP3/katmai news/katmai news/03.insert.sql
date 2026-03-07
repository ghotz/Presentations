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


INSERT Prodotti (descrizione, importo, dataAggiornamento)
VALUES	(N'Prodotto 1',11,getdate()),
		(N'Prodotto 2',22,getdate()),
		(N'Prodotto 3',33,getdate())
GO


select * from prodotti
