with XmlDeadlockReports as
(
  select convert(xml, event_data) as EventData
   from sys.fn_xe_file_target_read_file(N'system_health*.xel', NULL, NULL, NULL)
  where object_name = 'xml_deadlock_report'
) 
select EventData.value('(event/@timestamp)[1]', 'datetime2(7)') as TimeStamp,
       EventData.query('event/data/value/deadlock') as XdlFile
  from XmlDeadlockReports
 order by TimeStamp desc