--
-- This script is used to demonstrate new
-- show SQL Server Agent and WMI events
-- in SQL Server 2005
-- 
--
USE master;
GO

-- catalog view to verify which databases has broker enabled
SELECT name, is_broker_enabled, service_broker_guid FROM sys.databases;
GO

-- if broker is not eanble for msdb, enable it
--IF NOT EXISTS (
--	SELECT	*
--	FROM	sys.databases
--	WHERE	name = 'msdb'
--	  AND	is_broker_enabled = 1
--	)
--ALTER DATABASE msdb SET ENABLE_BROKER
--GO

-- change database context
USE tempdb;
GO

-- create a table to hold deadlock events
IF OBJECT_ID('DeadlockEvents', 'U') IS NOT NULL
BEGIN
    DROP TABLE DeadlockEvents ;
END ;
GO

CREATE TABLE DeadlockEvents
    (AlertTime DATETIME, DeadlockGraph XML) ;
GO

-- Add a job for the alert to run.
EXEC	msdb.dbo.sp_add_job
	@job_name = N'Capture Deadlock Graph'
,	@enabled = 1
,	@description = N'Job for responding to DEADLOCK_GRAPH events'
,	@owner_login_name = 'sa';
GO

-- Add a jobstep that inserts the current time and the deadlock graph into
-- the DeadlockEvents table.
EXEC	msdb.dbo.sp_add_jobstep
	@job_name = N'Capture Deadlock Graph'
,	@step_name = N'Insert graph into LogEvents'
,	@step_id = 1
,	@on_success_action = 1
,	@on_fail_action = 2
,	@subsystem = N'TSQL'
,	@command = N'INSERT INTO DeadlockEvents
                (AlertTime, DeadlockGraph)
                VALUES (getdate(), N''$(ESCAPE_SQUOTE(WMI(TextData)))'')'
,	@database_name = N'tempdb';
GO

-- Set the job server for the job to the current instance of SQL Server.
EXEC msdb.dbo.sp_add_jobserver @job_name = N'Capture Deadlock Graph' ;
GO

-- Add an alert that responds to all DEADLOCK_GRAPH events for
-- the default instance. To monitor deadlocks for a different instance,
-- change PROD1 to the name of the instance.
EXEC msdb.dbo.sp_add_alert
	@name=N'Respond to DEADLOCK_GRAPH', 
	@wmi_namespace=N'\\.\root\Microsoft\SqlServer\ServerEvents\MSSQLSERVER', 
    @wmi_query=N'SELECT * FROM DEADLOCK_GRAPH', 
	@include_event_description_in=1, 
    @job_name='Capture Deadlock Graph' ;
GO
--EXEC	msdb.dbo.sp_add_notification @alert_name=N'Respond to DEADLOCK_GRAPH'
--		, @operator_name=N'Gianluca Hotz', @notification_method =1 -- mail
		
-- now generate a dealock and query the table
SELECT * FROM DeadlockEvents ;
GO
