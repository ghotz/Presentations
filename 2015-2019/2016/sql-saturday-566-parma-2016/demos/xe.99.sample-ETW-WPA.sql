------------------------------------------------------------------------
--	Script:			xe.99.sample-ETW-WPA.sql
--	Description:	Esempio di integrazione xe/etw/WPA
--	Author:			Gianluca Hotz (SolidQ)
--	Copyright:		Attribution-NonCommercial-ShareAlike 3.0
------------------------------------------------------------------------

--
--	Parte del codice e' basato su serie di 31 articoli di Jonathan Kehayias
--	http://sqlblog.com/blogs/jonathan_kehayias/archive/2010/12/01/a-xevent-a-day-31-days-of-extended-events.aspx
--

------------------------------------------------------------------------
--	Comandi generali (non eseguire come parte della demo)
--
--	Per fare partire/fermare xperf:
--		xperf.exe -on Latency -stackwalk profile
--		xperf.exe -stop -d C:\temp\xperf\xe_test_system.etl
--
--	Lista sessioni ETW
--		logman query -ets
------------------------------------------------------------------------

------------------------------------------------------------------------
--	Creazione sessione con ETW come destinazione
------------------------------------------------------------------------
CREATE EVENT SESSION [etw_disk] ON SERVER 
ADD EVENT sqlos.wait_info(
    ACTION(sqlserver.database_id,sqlserver.session_id)),
ADD EVENT sqlserver.file_read(
    ACTION(sqlserver.session_id)),
ADD EVENT sqlserver.file_read_completed(
    ACTION(sqlserver.session_id)),
ADD EVENT sqlserver.sql_statement_completed(
    ACTION(sqlserver.database_id,sqlserver.plan_handle,sqlserver.session_id,sqlserver.sql_text)),
ADD EVENT sqlserver.sql_statement_starting(
    ACTION(sqlserver.database_id,sqlserver.plan_handle,sqlserver.session_id,sqlserver.sql_text)) 
ADD TARGET package0.etw_classic_sync_target
(
	SET	default_etw_session_logfile_path=N'C:\temp\xperf\xe_demo_disk.etl'
	,	default_etw_session_logfile_size_mb=(100)
)
WITH (MAX_DISPATCH_LATENCY=5 SECONDS, MAX_EVENT_SIZE=4096 KB, MEMORY_PARTITION_MODE=PER_CPU, TRACK_CAUSALITY=ON);
GO

------------------------------------------------------------------------
--	Fare partire Kernel Logger per eventi sistema operativo
--		logman start "NT Kernel Logger" /p "Windows Kernel Trace" (process,thread,disk) /o C:\temp\xperf\xe_demo_system.etl /ets
--	Fare partire sessione
------------------------------------------------------------------------
ALTER EVENT SESSION [etw_disk] ON SERVER
STATE = START;
GO

------------------------------------------------------------------------
--	Eseguire query onerosa
------------------------------------------------------------------------
DBCC DROPCLEANBUFFERS;
GO
SELECT
    100.00 * sum(case
                 when p_type like 'PROMO%'
                 then l_extendedprice*(1-l_discount)
                 else 0
           end) / sum(l_extendedprice * (1 - l_discount)) as
    promo_revenue
FROM
    [TPCH-2_16_0].dbo.lineitem,
    [TPCH-2_16_0].dbo.part
WHERE
    l_partkey = p_partkey
    and l_shipdate >= '1995-09-01'
    and l_shipdate < dateadd(mm, 1, '1995-09-01');
GO

------------------------------------------------------------------------
--	Fermare Kernel Logger
--		logman update "NT Kernel Logger" /fd /ets 
--		logman stop "NT Kernel Logger" /ets
--
--	Fermare sessione XE
--		logman update XE_DEFAULT_ETW_SESSION /fd /ets 
--		logman stop XE_DEFAULT_ETW_SESSION /ets
--
--	Aprire i file con Windows Performance Analyzer
--
--	I merge con xperf non funziona perche' i manifest sono diversi.
--		xperf -merge xe_demo_disk.etl xe_demo_system.etl xe_demo_merged.etl
--
--	Per fare il merge in CSV
--		tracerpt xe_demo_disk.etl xe_demo_system.etl -o xe_demo_merged.csv -of CSV
------------------------------------------------------------------------

------------------------------------------------------------------------
--	Eliminare la sessione XE
------------------------------------------------------------------------
DROP EVENT SESSION [etw_disk] ON SERVER;
GO