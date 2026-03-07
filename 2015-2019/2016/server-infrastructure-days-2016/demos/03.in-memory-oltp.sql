
-- Soluzione VS2015 C:\Users\Gianluca\Source\Repos\sql-server-samples\samples\features\in-memory\ticket-reservations
-- Eseguibile in C:\Users\Gianluca\Source\Repos\sql-server-samples\samples\features\in-memory\ticket-reservations\DemoWorkload\obj\Release

--	1. Eseguire DemoWorkload.exe per qualche dozzina di secondi per creare baseline
--	2. Notare numero di tx/sec tra 7000 e 8000 con utilizzo CPU attorno al 40% e sui 40k latches/sec
--	3. Modificare tabella da disk-based a in-memory optimized e procedura in procedura compilata
--	4. Pulish del progetto database facendo notare migrazione dei dati
--	5. Eseguire nuovamente Start in DemoWorkload.exe
--	6. Nota differenza tx/sec tra 23000 e 25000 con utilizzo CPU attorno al 100% e 0 latches/sec

USE TicketReservations;
GO

-- Cleanup
-- Eliminare righe quando si torna a disk-based altrimenti INSERT/SELECT da temporanea ci mette troppo tempo
DELETE [dbo].[TicketReservationDetail]
GO
--ALTER DATABASE CURRENT SET DELAYED_DURABILITY = FORCED
--GO
--ALTER DATABASE CURRENT SET DELAYED_DURABILITY = DISABLED
--GO
