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
codice char(4) primary key,
descrizione varchar(35),
importo decimal(10,2)
)
go

CREATE TABLE tmpProdotti
(
codice char(4) primary key,
descrizione varchar(35),
importo decimal(10,2)
)
go

insert Prodotti values ('AZTN','111111',12.10)
insert Prodotti values ('MSFT','222222',22.00)
insert Prodotti values ('ABCD','333333',4.56)
insert Prodotti values ('XXXX','999999',8)

insert tmpProdotti values ('AZTN','111111',8.10)
insert tmpProdotti values ('MSFT','222222',24.20)
insert tmpProdotti values ('ABCD','333333',4.56)
insert tmpProdotti values ('DEFG','444444',8.16)
insert tmpProdotti values ('XXXX','999999',-8)

select * from Prodotti
select * from tmpProdotti

-- Apply changes to the Stock table based on daily trades 
-- tracked in the Trades table. Delete a row from the Stock table 
-- if all the stock has been sold. Update the quantity in the Stock 
-- table if you still hold some stock after the daily trades. Insert 
-- a new row if you acquired a new Stock. 
-- As a result, TXN is deleted, SBUX inserted, MSFT updated
MERGE Prodotti S -- target table
        USING tmpProdotti T -- source table
        ON S.codice = T.codice 
        WHEN MATCHED AND (S.importo + T.importo = 0) THEN
                DELETE 
        WHEN MATCHED THEN
                UPDATE SET 
					S.importo = T.importo,
					S.descrizione = T.descrizione
        WHEN NOT MATCHED THEN
                INSERT VALUES (codice, descrizione, importo)
        -- output details of INSERT/UPDATE/DELETE operations
        -- made on the target table
        OUTPUT $action, inserted.codice, inserted.importo [ins importo], deleted.importo [del importo]; 


select * from Prodotti
select * from tmpProdotti


MERGE Prodotti S -- target table
        USING 
		(
			select 'AZTN', '111111', 15.00 union
			select 'MSFT', '222222', 15.00 
		) as T (codice, descrizione, importo)

        ON S.codice = T.codice 
        WHEN MATCHED AND (S.importo + T.importo = 0) THEN
                DELETE 
        WHEN MATCHED THEN
                UPDATE SET 
					S.importo = T.importo,
					S.descrizione = T.descrizione
        WHEN NOT MATCHED THEN
                INSERT VALUES (codice, descrizione, importo)
        -- output details of INSERT/UPDATE/DELETE operations
        -- made on the target table
        OUTPUT $action, inserted.codice, inserted.importo [ins importo], deleted.importo [del importo]; 


select * from Prodotti
select * from tmpProdotti
