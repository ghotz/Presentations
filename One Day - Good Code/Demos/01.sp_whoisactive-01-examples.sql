------------------------------------------------------------------------
-- Script:		sp_whoisactive-01-examples.sql
-- Copyright:	2018 Gianluca Hotz
-- License:		MIT License
-- Credits:
------------------------------------------------------------------------

-- Case 1: get waiting tasks (defaults to running, specific wait or open transactions)
EXEC sp_whoisactive;
GO

-- Case 2: add tasks wait details for parallel queries
EXEC sp_whoisactive @get_task_info = 2;
GO

-- Case 3: add execution Plans
EXEC sp_whoisactive @get_task_info = 2, @get_plans = 1;
GO

-- Case 4: get again waiting tasks (defaults to running, specific wait or open transactions)
EXEC sp_whoisactive @get_task_info = 2;
GO

-- Case 5: add find block leaders (column blocked_session_count)
EXEC sp_whoisactive @get_task_info = 2, @find_block_leaders = 1;
GO

-- Normally we would analyze blocking info with system procedure such as this one
EXEC sp_lock;
GO

-- Case 6: add blocking details (column locks)
EXEC sp_whoisactive @get_task_info = 2, @find_block_leaders = 1, @get_locks = 1;
GO

-- Case 7: measure resource usage over a period of time (in seconds)
EXEC sp_whoisactive @get_task_info = 2, @delta_interval = 5;
GO

-- Case 8: show all spids
EXEC sp_whoisactive @get_task_info=2, @show_sleeping_spids=2
GO

-- Help
EXEC sp_whoisactive @help = 1;
GO

-- Return schema to automate monitoring
DECLARE @sqlstmt nvarchar(max);
EXEC	sp_whoisactive @return_schema = 1, @schema = @sqlstmt OUTPUT;
PRINT	@sqlstmt;
GO

-- Other examples
EXEC sp_whoisactive @get_task_info=2, @show_sleeping_spids=0, @get_outer_command = 1, @get_additional_info = 1, @output_column_list = '[dd%][session_id][sql_text][login_name][wait_info][host_name][database_name][block%][tasks][tran_log%][cpu%][temp%][reads%][writes%][context%][physical%][program_name][query_plan][locks][sql_command][%]';
EXEC sp_whoisactive @get_task_info=2, @show_sleeping_spids=0, @get_plans = 1, @find_block_leaders = 1, @get_locks = 1,  @get_outer_command = 1, @get_additional_info = 1, @output_column_list = '[dd%][session_id][sql_text][login_name][wait_info][host_name][database_name][block%][tasks][tran_log%][cpu%][temp%][reads%][writes%][context%][physical%][program_name][query_plan][locks][sql_command][%]';
GO
