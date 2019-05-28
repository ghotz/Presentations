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