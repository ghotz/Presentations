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
--	Come estrarre i deadlock graph dalla sessione system_health
--
--	Nota per le versioni precedenti la 2012, vedere questi link
--	http://www.sqlservercentral.com/articles/deadlock/65658/
--	https://connect.microsoft.com/SQLServer/feedback/details/404168/invalid-xml-in-extended-events-xml-deadlock-report-output
------------------------------------------------------------------------

--	Importante: eseguire prima gli script per creare il deadlock
SELECT
	XQ.event_node.value('(@name)[1]', 'varchar(50)') AS event_name
,	XQ.event_node.value('(@package)[1]', 'varchar(50)') AS package_name
,	DATEADD(hh , DATEDIFF(hh, GETUTCDATE(), CURRENT_TIMESTAMP)
	, XQ.event_node.value('(@timestamp)[1]', 'datetime2')) AS [timestamp]
,	XQ.event_node.query('(data/value/deadlock)[1]') as xml_report
FROM	(
		SELECT	CAST(XT.target_data AS xml) AS target_data
		FROM	sys.dm_xe_sessions AS XS
		JOIN	sys.dm_xe_session_targets AS XT
		  ON	XS.[address] = XT.event_session_address
		WHERE	XS.name = 'system_health'
		  AND	XT.target_name = 'ring_buffer'	
		) AS ED
CROSS
APPLY	target_data.nodes('RingBufferTarget/event[@name=(''xml_deadlock_report'')]') as XQ(event_node);
GO

------------------------------------------------------------------------
--	Per visualizzare il report in formato grafico
--		1	Aprire il contenuto del campo xml_report
--		2	Salvare con estensione .xdl
--		3	Caricare nel Management Studio
------------------------------------------------------------------------


------------------------------------------------------------------------
--	Estrarre informazioni relative ai processi coinvolti
------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#deadlocks') IS NOT NULL
	DROP TABLE #deadlocks;
GO

WITH	XmlDataSet AS
(
	SELECT	CAST(xet.target_data AS XML) AS XMLDATA,*
	FROM	sys.dm_xe_session_targets AS xet
	INNER
	JOIN	sys.dm_xe_sessions AS xe
	  ON	xe.address = xet.event_session_address
	WHERE	xe.name = 'system_health'
	  AND	target_name = 'ring_buffer'
)
SELECT	CAST(C.query('.') as xml) AS EventXML
INTO	#deadlocks
FROM	XmlDataSet AS a
CROSS
APPLY	a.XMLDATA.nodes('/RingBufferTarget/event[@name=''xml_deadlock_report'']') AS T(C)
--WHERE	C.query('.').value('(/event/@name)[1]', 'varchar(255)') IN ('xml_deadlock_report');
GO

SELECT	DeadlockProcesses.value('(@id)[1]','varchar(50)') as id
,		DeadlockProcesses.value('(@taskpriority)[1]','bigint') as taskpriority
,		DeadlockProcesses.value('(@logused)[1]','bigint') as logused
,		DeadlockProcesses.value('(@waitresource)[1]','varchar(100)') as waitresource
,		DeadlockProcesses.value('(@waittime)[1]','bigint') as waittime
,		DeadlockProcesses.value('(@ownerId)[1]','bigint') as ownerId
,		DeadlockProcesses.value('(@transactionname)[1]','varchar(50)') as transactionname
,		DeadlockProcesses.value('(@lasttranstarted)[1]','varchar(50)') as lasttranstarted
,		DeadlockProcesses.value('(@XDES)[1]','varchar(20)') as XDES
,		DeadlockProcesses.value('(@lockMode)[1]','varchar(5)') as lockMode
,		DeadlockProcesses.value('(@schedulerid)[1]','bigint') as schedulerid
,		DeadlockProcesses.value('(@kpid)[1]','bigint') as kpid
,		DeadlockProcesses.value('(@status)[1]','varchar(20)') as status
,		DeadlockProcesses.value('(@spid)[1]','bigint') as spid
,		DeadlockProcesses.value('(@sbid)[1]','bigint') as sbid
,		DeadlockProcesses.value('(@ecid)[1]','bigint') as ecid
,		DeadlockProcesses.value('(@priority)[1]','bigint') as priority
,		DeadlockProcesses.value('(@trancount)[1]','bigint') as trancount
,		DeadlockProcesses.value('(@lastbatchstarted)[1]','varchar(50)') as lastbatchstarted
,		DeadlockProcesses.value('(@lastbatchcompleted)[1]','varchar(50)') as lastbatchcompleted
,		DeadlockProcesses.value('(@clientapp)[1]','varchar(150)') as clientapp
,		DeadlockProcesses.value('(@hostname)[1]','varchar(50)') as hostname
,		DeadlockProcesses.value('(@hostpid)[1]','bigint') as hostpid
,		DeadlockProcesses.value('(@loginname)[1]','varchar(150)') as loginname
,		DeadlockProcesses.value('(@isolationlevel)[1]','varchar(150)') as isolationlevel
,		DeadlockProcesses.value('(@xactid)[1]','bigint') as xactid
,		DeadlockProcesses.value('(@currentdb)[1]','bigint') as currentdb
,		DeadlockProcesses.value('(@lockTimeout)[1]','bigint') as lockTimeout
,		DeadlockProcesses.value('(@clientoption1)[1]','bigint') as clientoption1
,		DeadlockProcesses.value('(@clientoption2)[1]','bigint') as clientoption2
FROM	#deadlocks AS D
CROSS APPLY eventxml.nodes('//deadlock/process-list/process') AS R(DeadlockProcesses);
GO