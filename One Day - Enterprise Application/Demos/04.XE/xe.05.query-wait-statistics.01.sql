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

------------------------------------------------------------------------
--	Creazione della sessione
--
--	Istruzioni per crearla in SSMS 2012
--		1	In Management/Extended Events/Session selezione New Session
--		2	In General dare il nome query_wait
--		3	In General selezionare il Template Query Wait Statistics
--		4	In Events->Configure rimuove da tutti gli eventi il
--			predicato "sqlserver.session_id divides_by_unint64 5"
--			perche' il template e' pensate per registrare le query a
--			campione prendendo solo quelle con spid divisibile per 5
--		5	Lasciare tutte le impostazioni predefinite
------------------------------------------------------------------------
-- Creazione sessione generata direttamente da SSMS
CREATE EVENT SESSION [query_wait] ON SERVER 
ADD EVENT sqlos.wait_info(
    ACTION(sqlserver.client_app_name,sqlserver.database_id,sqlserver.query_hash,sqlserver.query_plan_hash,sqlserver.session_id)
    WHERE ([package0].[greater_than_uint64]([sqlserver].[database_id],(4)) AND [package0].[equal_boolean]([sqlserver].[is_system],(0)))),
--ADD EVENT sqlos.wait_info_external(
--    ACTION(sqlserver.client_app_name,sqlserver.database_id,sqlserver.query_hash,sqlserver.query_plan_hash,sqlserver.session_id)
--    WHERE ([package0].[greater_than_uint64]([sqlserver].[database_id],(4)) AND [package0].[equal_boolean]([sqlserver].[is_system],(0)))),
ADD EVENT sqlserver.rpc_completed(
    ACTION(sqlserver.client_app_name,sqlserver.database_id,sqlserver.query_hash,sqlserver.session_id)
    WHERE ([package0].[greater_than_uint64]([sqlserver].[database_id],(4)) AND [package0].[equal_boolean]([sqlserver].[is_system],(0)))),
ADD EVENT sqlserver.rpc_starting(
    ACTION(sqlserver.client_app_name,sqlserver.database_id,sqlserver.query_hash,sqlserver.session_id)
    WHERE ([package0].[greater_than_uint64]([sqlserver].[database_id],(4)) AND [package0].[equal_boolean]([sqlserver].[is_system],(0)))),
ADD EVENT sqlserver.sp_statement_completed(SET collect_object_name=(1),collect_statement=(1)
    ACTION(sqlserver.client_app_name,sqlserver.database_id,sqlserver.query_hash,sqlserver.query_plan_hash,sqlserver.session_id)
    WHERE ([package0].[greater_than_uint64]([sqlserver].[database_id],(4)) AND [package0].[equal_boolean]([sqlserver].[is_system],(0)))),
ADD EVENT sqlserver.sp_statement_starting(
    ACTION(sqlserver.client_app_name,sqlserver.database_id,sqlserver.query_hash,sqlserver.query_plan_hash,sqlserver.session_id)
    WHERE ([package0].[greater_than_uint64]([sqlserver].[database_id],(4)) AND [package0].[equal_boolean]([sqlserver].[is_system],(0)))),
ADD EVENT sqlserver.sql_batch_completed(
    ACTION(sqlserver.client_app_name,sqlserver.database_id,sqlserver.query_hash,sqlserver.session_id)
    WHERE ([package0].[greater_than_uint64]([sqlserver].[database_id],(4)) AND [package0].[equal_boolean]([sqlserver].[is_system],(0)))),
ADD EVENT sqlserver.sql_batch_starting(
    ACTION(sqlserver.client_app_name,sqlserver.database_id,sqlserver.query_hash,sqlserver.session_id)
    WHERE ([package0].[greater_than_uint64]([sqlserver].[database_id],(4)) AND [package0].[equal_boolean]([sqlserver].[is_system],(0)))),
ADD EVENT sqlserver.sql_statement_completed(
    ACTION(sqlserver.client_app_name,sqlserver.database_id,sqlserver.query_hash,sqlserver.query_plan_hash,sqlserver.session_id)
    WHERE ([package0].[greater_than_uint64]([sqlserver].[database_id],(4)) AND [package0].[equal_boolean]([sqlserver].[is_system],(0)))),
ADD EVENT sqlserver.sql_statement_starting(
    ACTION(sqlserver.client_app_name,sqlserver.database_id,sqlserver.query_hash,sqlserver.query_plan_hash,sqlserver.session_id)
    WHERE ([package0].[greater_than_uint64]([sqlserver].[database_id],(4)) AND [package0].[equal_boolean]([sqlserver].[is_system],(0)))) 
ADD TARGET package0.event_file(SET filename=N'C:\temp\xevents\query_wait_analysis.xel')
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=OFF)
GO

-- Start della sessione (in SSMS)
ALTER EVENT SESSION [query_wait] ON SERVER STATE=START;
GO

DBCC DROPCLEANBUFFERS;
GO

------------------------------------------------------------------------
--	Esegure le query del TPC-H
--	!!"C:\Users\Gianluca\OneDrive\Documents\Presentations\UGISS\20161126 SQL Saturday #566\Demos\xe.05.query-wait-statistics.02.start-workload.bat"
--	!!"C:\Users\Gianluca\OneDrive\Documents\Presentations\UGISS\20161126 SQL Saturday #566\Demos\xe.05.query-wait-statistics.07.start-aworks-workload.bat"
--
--	Nota: la sessione e' impostata di default per filtrare anche i
--	database con id minore di 5 per escludere quelli di sistema ma
--	il filtro viene applicato al database di contesto delle connessione,
--	quindi occorre fare attenzione che questo non sia uno di sistema.
------------------------------------------------------------------------

-- Stop della sessione (in SSMS)
ALTER EVENT SESSION [query_wait] ON SERVER STATE=STOP;
GO

------------------------------------------------------------------------
--	Istruzioni per analisi in SSMS 2012
--		1	Aprire il visualizzatore della destinazione event_file
--		2	Ordinare per physical_reads e trovare statement piu' oneroso
--		3	Prendere e filtrare per attach_activity_id.guid
--		4	Verificare Wait Stats raggruppando e aggregando per duration
--		5	Recuperare query_plan_hash e prendere piano di esecuzione
--			dalla cache dei piani di esecuzione
------------------------------------------------------------------------

--	decodifica query_plan_hash che in Extended Events e' unit64 ma
--	SQL Server non supporta quel tipo
--	Maggiori info:	http://sqlscope.wordpress.com/2013/10/20/query-hash-and-plan-hash-conversions
--					http://blogs.msdn.com/b/sql_pfe_blog/archive/2013/08/19/correlating-xe-query-hash-and-query-plan-hash-to-sys-dm-exec-query-stats-in-order-to-retrieve-execution-plans-for-high-resource-statements.aspx
DECLARE @m bigint = 0x8000000000000000
DECLARE	@query_plan_hash decimal(20, 0) = 5632262870282198874

SELECT
	-- check topmost bit of extended event query hash
	CASE WHEN @query_plan_hash < CONVERT(DECIMAL(20,0), @m) * -1
	-- if topmost bit is not set convert to bigint and then convert to binary(8)
	THEN CONVERT(BINARY(8),CONVERT(BIGINT,@query_plan_hash))
	-- if topmost bit is set subtract topmost bit value, convert to bigint, set topmost bit and convert to binary(8)
	ELSE CONVERT(BINARY(8),CONVERT(BIGINT,@query_plan_hash - CONVERT(DECIMAL(20,0),@m)*-1)|@m)
	END AS dmv_query_plan_hash
GO

SELECT	query_plan_hash, query_plan
FROM	sys.dm_exec_query_stats AS QS
CROSS
APPLY	sys.dm_exec_query_plan(QS.plan_handle) AS QP
WHERE	query_plan_hash = 0x4E29D13D50CADF5A;
GO

-- Analisi dati sessione con T-SQL
SELECT
	XQ.event_node.value('(@name)[1]', 'varchar(50)') AS event_name
,	XQ.event_node.value('(@package)[1]', 'varchar(50)') AS package_name
,	DATEADD(hh , DATEDIFF(hh, GETUTCDATE(), CURRENT_TIMESTAMP)
	, XQ.event_node.value('(@timestamp)[1]', 'datetime2')) AS [timestamp]
,	XQ.event_node.value('(data[@name="duration"]/value)[1]', 'bigint') as duration
,	XQ.event_node.value('(data[@name="cpu_time"]/value)[1]', 'bigint') as cpu_time
,	XQ.event_node.value('(data[@name="physical_reads"]/value)[1]', 'bigint') as physical_reads
,	XQ.event_node.value('(data[@name="logical_reads"]/value)[1]', 'bigint') as logical_reads
,	XQ.event_node.value('(data[@name="writer"]/value)[1]', 'bigint') as writes
,	XQ.event_node.value('(data[@name="row_count"]/value)[1]', 'bigint') as row_count
,	XQ.event_node.value('(action[@name="query_hash"]/value)[1]', 'decimal(20,0)') as query_hash	
,	XQ.event_node.value('(action[@name="query_plan_hash"]/value)[1]', 'decimal(20,0)') as query_plan_hash	
,	XQ.event_node.value('(data[@name="statement"]/value)[1]', 'nvarchar(max)') as [statement]
FROM	(
		SELECT	CAST(event_data AS xml) AS event_data
		FROM	sys.fn_xe_file_target_read_file('C:\temp\xevents\query_wait_analysis*.xel', NULL, NULL, NULL)
		) AS ED
CROSS
APPLY	event_data.nodes('event[@name=''sql_statement_completed'']') as XQ(event_node)
ORDER BY	physical_reads DESC;
GO
