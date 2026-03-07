------------------------------------------------------------------------
--	Script:			xe.06.spot-query-statistics.01.sql
--	Description:	Misurare batch e query in maniera puntuale
--	Author:			Gianluca Hotz (SolidQ)
--	Copyright:		Attribution-NonCommercial-ShareAlike 3.0
------------------------------------------------------------------------

------------------------------------------------------------------------
--	Creiamo una sessione per tracciare l'esecuzione di batch per
--	la connessione corrente.
------------------------------------------------------------------------
IF EXISTS(SELECT * FROM	sys.dm_xe_sessions WHERE name = N'spot_trace')
	ALTER EVENT SESSION [spot_trace] ON SERVER STATE=STOP;
IF EXISTS(SELECT * FROM	sys.server_event_sessions WHERE	name = N'spot_trace')
	DROP EVENT SESSION [spot_trace] ON SERVER;
GO
DECLARE	@SessionID nvarchar(10) = CAST(@@SPID AS nvarchar(10));
DECLARE	@SessiomStmt nvarchar(MAX) = N'
CREATE EVENT SESSION [spot_trace] ON SERVER 
ADD EVENT sqlos.wait_info(
    ACTION(sqlserver.session_id)
    WHERE ([sqlserver].[session_id]=(' + @SessionID + '))),
--ADD EVENT sqlos.wait_info_external(
--    ACTION(sqlserver.session_id)
--    WHERE ([sqlserver].[session_id]=(' + @SessionID + '))),
ADD EVENT sqlserver.sql_batch_starting(SET collect_batch_text=(1)
    ACTION(sqlserver.session_id)
    WHERE ([sqlserver].[session_id]=(' + @SessionID + '))),
ADD EVENT sqlserver.sql_batch_completed(SET collect_batch_text=(1)
    ACTION(sqlserver.session_id)
    WHERE ([sqlserver].[session_id]=(' + @SessionID + ')))
ADD TARGET package0.event_file(SET filename=N''C:\temp\xevents\spot_trace.xel'')
WITH (TRACK_CAUSALITY=ON);
';
EXEC (@SessiomStmt);
GO
ALTER EVENT SESSION [spot_trace] ON SERVER STATE=START;
GO
DBCC DROPCLEANBUFFERS;
GO
SELECT COUNT(*) FROM [AdventureWorks2012].[Sales].[SalesOrderDetail];
GO
ALTER EVENT SESSION [spot_trace] ON SERVER STATE=STOP;
GO

------------------------------------------------------------------------
--	Creiamo una sessione per tracciare l'esecuzione di batch e
--	e comandi SQL per la connessione corrente.
------------------------------------------------------------------------
IF EXISTS(SELECT * FROM	sys.dm_xe_sessions WHERE name = N'spot_trace')
	ALTER EVENT SESSION [spot_trace] ON SERVER STATE=STOP;
IF EXISTS(SELECT * FROM	sys.server_event_sessions WHERE	name = N'spot_trace')
	DROP EVENT SESSION [spot_trace] ON SERVER;
GO
DECLARE	@SessionID nvarchar(10) = CAST(@@SPID AS nvarchar(10));
DECLARE	@SessiomStmt nvarchar(MAX) = N'
CREATE EVENT SESSION [spot_trace] ON SERVER 
ADD EVENT sqlos.wait_info(
    ACTION(sqlserver.session_id)
    WHERE ([sqlserver].[session_id]=(' + @SessionID + '))),
--ADD EVENT sqlos.wait_info_external(
--    ACTION(sqlserver.session_id)
--    WHERE ([sqlserver].[session_id]=(' + @SessionID + '))),
ADD EVENT sqlserver.sql_batch_starting(SET collect_batch_text=(1)
    ACTION(sqlserver.session_id)
    WHERE ([sqlserver].[session_id]=(' + @SessionID + '))),
ADD EVENT sqlserver.sql_batch_completed(SET collect_batch_text=(1)
    ACTION(sqlserver.session_id)
    WHERE ([sqlserver].[session_id]=(' + @SessionID + '))),
ADD EVENT sqlserver.sql_statement_completed(SET collect_parameterized_plan_handle=(1)
    ACTION(sqlserver.session_id)
    WHERE ([sqlserver].[session_id]=(' + @SessionID + ')))
ADD TARGET package0.event_file(SET filename=N''C:\temp\xevents\spot_trace.xel'')
WITH (TRACK_CAUSALITY=ON);
';
EXEC (@SessiomStmt);
GO
ALTER EVENT SESSION [spot_trace] ON SERVER STATE=START;
GO
DBCC DROPCLEANBUFFERS;
SELECT COUNT(*) FROM [AdventureWorks2012].[Sales].[SalesOrderDetail];
SELECT COUNT(*) FROM [AdventureWorks2012].[Sales].[SalesOrderDetail];
GO
ALTER EVENT SESSION [spot_trace] ON SERVER STATE=STOP;
GO