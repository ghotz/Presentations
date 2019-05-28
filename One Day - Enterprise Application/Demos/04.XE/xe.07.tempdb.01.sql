------------------------------------------------------------------------
-- Copyright:   2016 Gianluca Hotz
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

USE tempdb;
GO

------------------------------------------------------------------------
--	Per monitorare l'utilizzo del tempdb, i Books Online forniscono
--	http://technet.microsoft.com/en-us/library/ms176029(v=sql.105).aspx
--	una serie di query per tracciare l'uso del tempdb basandosi
--	sue tre DMV
--		sys.dm_db_file_space_usage
--		sys.dm_db_task_space_usage
--		sys.dm_db_session_space_usage
--
--	Quest'ultima e' particolarmente utile perche' mantiene il cumulato
--	per la durata della sessione (eseguire query altra connessione)
------------------------------------------------------------------------
SELECT	session_id
,		DB_NAME(database_id) AS database_name
,		MBAllocated = ((user_objects_alloc_page_count + internal_objects_alloc_page_count) * 8192) / 1024.0 / 1014.0
FROM	sys.dm_db_session_space_usage
WHERE	session_id = 83;
GO

------------------------------------------------------------------------
--	Il problema e' quando le sessioni vengono aperte e chiuse, anche se
--	facessimo degli snapshot ad intervalli regolari, potremmo mancare
--	delle query (a meno di non farli ad intervalli poco realistici).
------------------------------------------------------------------------
CREATE EVENT SESSION [track_tempdb] ON SERVER 
ADD EVENT sqlserver.file_write_completed(
	ACTION(sqlserver.query_hash, sqlserver.sql_text)	-- Nota: normalmente solo query_hash per diminuire dati tracciati
	WHERE ([database_id]=(2))) 
ADD TARGET package0.event_file(SET filename=N'C:\temp\xevents\track_tempdb.xel')
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=OFF)
GO

-- Start della sessione
ALTER EVENT SESSION [track_tempdb] ON SERVER STATE=START;
GO

------------------------------------------------------------------------
-- Esecuzione dello script xe.07.tempdb.02.query.sql
------------------------------------------------------------------------

-- Stop della sessione
ALTER EVENT SESSION [track_tempdb] ON SERVER STATE=STOP;
GO

------------------------------------------------------------------------
--	Visualizzazione e analisi in SSMS
------------------------------------------------------------------------


DROP EVENT SESSION [track_tempdb] ON SERVER;
GO
------------------------------------------------------------------------
--	Un altro scenario interessante e' quello di tracciare la contention
--	delle pagine di allocazione nel tempdb, questo articolo spiega
--	passo-passo come fare https://www.simple-talk.com/sql/database-administration/optimizing-tempdb-configuration-with-sql-server-2012-extended-events
------------------------------------------------------------------------
