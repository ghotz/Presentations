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
--              The above copyright notice and this permission notice
--              shall be included in all copies or substantial portions
--              of the Software.
--              THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
--              ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
--              LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
--              FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
--              EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
--              FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
--              AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--              OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
--              OTHER DEALINGS IN THE SOFTWARE.
-- Credits:	    
------------------------------------------------------------------------
USE master;
GO

-- prima di tutto dobbiamo abilitare la funzionalità di Stretch Database
EXEC sp_configure 'remote data archive' , '1';  
GO
RECONFIGURE;
GO  

USE TemporalDB;
GO
-- creiamo una master key per proteggere le credenziali
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Passw0rd!'; 
GO
-- creiamo le credenziali per accedere ad Azure SQL Database
-- DROP DATABASE SCOPED CREDENTIAL ghotz  
CREATE DATABASE SCOPED CREDENTIAL ghotz  
    WITH IDENTITY = '+++++' , SECRET = '*****' ;
GO 

-- specifichiamo il server Azure SQL Database e le credenziali con cui accedere
ALTER DATABASE TemporalDB
SET REMOTE_DATA_ARCHIVE = ON
(	
	SERVER = 'ghotz.database.windows.net'
,	CREDENTIAL = ghotz
);  
GO

-- creiamo una funzione per discriminare le righe da archiviare
-- (in questo caso per data fine periodo)
CREATE FUNCTION dbo.fn_StretchByEndTime(@systemEndTime datetime2)
RETURNS TABLE   
WITH SCHEMABINDING    
AS    
RETURN
	SELECT	1 AS is_eligible   
	WHERE	@systemEndTime < CONVERT(datetime2, '2016-11-17 00:00:00', 120);
GO

-- verificare il piano di esecuzione prima di attivare
SELECT *, [SP_FROM], [SP_TO] FROM [SP] FOR SYSTEM_TIME ALL;
GO

-- attiviamo lo spostamento delle righe
ALTER TABLE HISTORY.SP_HIST  
SET (   
	REMOTE_DATA_ARCHIVE = ON (   
		FILTER_PREDICATE = dbo.fn_StretchByEndTime([SP_TO])
    ,	MIGRATION_STATE = OUTBOUND
	)  
); 
GO

-- verificare piano di esecuzione con query remota
SELECT *, [SP_FROM], [SP_TO] FROM [SP] FOR SYSTEM_TIME ALL;
GO

-- disabilita lo spostamento delle righe
--ALTER TABLE HISTORY.SP_HIST  
--SET ( REMOTE_DATA_ARCHIVE = OFF_WITHOUT_DATA_RECOVERY ( MIGRATION_STATE = PAUSED )) ;
--GO

-- riporta le righe dall'archivio remoto in locale e disabilita lo Stretch
ALTER TABLE HISTORY.SP_HIST  
SET (REMOTE_DATA_ARCHIVE = ON (MIGRATION_STATE = INBOUND));
GO

-- verifichiamo nuovamente il piano di esecuzione
SELECT *, [SP_FROM], [SP_TO] FROM [SP] FOR SYSTEM_TIME ALL;
GO
