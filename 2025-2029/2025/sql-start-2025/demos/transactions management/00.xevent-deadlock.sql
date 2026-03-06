----------------------------------------------------------------------
-- Script:			10.xevent-deadlock.sql
-- Author:			Herbert Albert (Solid Quality Mentors)
-- Copyright:		Attribution-NonCommercial-ShareAlike 2.5
-- Version:			SQL Server 2008 SP1 
-- Tab/indent size:	4
------------------------------------------------------------------------


-- Which event for deadlock exists?

SELECT xp.[name], xo.*
FROM sys.dm_xe_objects xo, sys.dm_xe_packages xp
WHERE xp.[guid] = xo.[package_guid]
  AND xo.[object_type] = 'event'
  AND xo.name like '%dead%'
ORDER BY xo.[name];

-- what columns are exposed?

select * from 
 sys.dm_xe_object_columns
where [object_name] = 'xml_deadlock_report'

-- Destination (target) of the event:

SELECT xp.[name], xo.*
FROM sys.dm_xe_objects xo, sys.dm_xe_packages xp
WHERE xp.[guid] = xo.[package_guid]
  AND xo.[object_type] = 'target'
ORDER BY xp.[name], xo.[name];

-- Now we’re ready to create the Extended Event with the following code:

create event session xe_deadlock on server
add event sqlserver.xml_deadlock_report
    (action (sqlserver.database_id, sqlserver.sql_text))
add target package0.asynchronous_file_target
    (set filename=N'c:\temp\xe_deadlock.xel', 
    metadatafile=N'c:\temp\xe_deadlock.xem');
    
 -- start the Extended Event:

alter event session xe_deadlock on server state = start;


-- find out if we have any row:
-- wait a few seconds

select COUNT(*)
from sys.fn_xe_file_target_read_file
('c:\temp\xe_deadlock*.xel', 'c:\temp\xe_deadlock*.xem', null, null)

--Some XPath querying:

--select 
--  xml_data 
--  , xml_data.value('(/event[@name=''xml_deadlock_report'']/@timestamp)[1]','datetime') [time]
--  ,	CAST(REPLACE (REPLACE (
--	xml_data.value('(/event/data/value)[1]','nvarchar(max)') , '<deadlock-list>',
--	 '<deadlock-list><deadlock victim="'
--	 +(CAST(REPLACE (REPLACE (xml_data.value('(/event/data/value)[1]','nvarchar(max)') ,
--	  '<deadlock-list>', '<deadlock-list><deadlock>'), '<process-list>'
--	  ,'</victim-list><process-list>') as  xml)).value('(//victimProcess/@id)[1]','nvarchar(256)')
--	  +'">'), '<process-list>','</victim-list><process-list>') as  xml) as SaveAsXDL
--	from 
--(select object_name as event, CONVERT(xml, event_data) as xml_data
--from sys.fn_xe_file_target_read_file
--('c:\temp\xe_deadlock*.xel', 'c:\temp\xe_deadlock*.xem', null, null)
--) v order by time

--REPLACE needed because of a bug in the engine
--see: https://connect.microsoft.com/SQLServer/feedback/ViewFeedback.aspx?FeedbackID=404168&wa=wsignin1.0#
--and Jonathan Kehayias article: http://www.sqlservercentral.com/articles/deadlock/65658/
--there you can also information how to retrieve deadlock information out of the default Xevent session

SELECT 
CONVERT(xml, event_data).query('/event/data/value/child::*') as deadlock,
CONVERT(xml, event_data).value('(event[@name="xml_deadlock_report"]/@timestamp)[1]','datetime') AS Execution_Time
FROM sys.fn_xe_file_target_read_file('c:\temp\xe_deadlock*.xel', 'c:\temp\xe_deadlock*.xem', null, null)
WHERE object_name like 'xml_deadlock_report'

--CLEANUP

drop event session xe_deadlock on SERVER

