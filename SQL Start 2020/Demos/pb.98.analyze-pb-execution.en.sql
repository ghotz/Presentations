------------------------------------------------------------------------
-- Copyright:   2019 Gianluca Hotz
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

-- Find out queries against external tables
SELECT	DR.execution_id, ST.*, DR.*
FROM	sys.dm_exec_distributed_requests AS DR
CROSS
APPLY	sys.dm_exec_sql_text(DR.sql_handle) AS ST
WHERE	ST.[text] LIKE '%Orders%'
ORDER BY DR.end_time DESC;
GO

-- Find your execution_id and use this for the next queries
SELECT * FROM sys.dm_exec_distributed_request_steps	WHERE execution_id = 'QID1430' ORDER BY step_index;
SELECT * FROM sys.dm_exec_distributed_sql_requests	WHERE execution_id = 'QID1430' ORDER BY step_index, compute_node_id, distribution_id;
SELECT * FROM sys.dm_exec_dms_workers				WHERE execution_id = 'QID1430' ORDER BY step_index, dms_step_index, compute_node_id, distribution_id;
SELECT * FROM sys.dm_exec_external_work				WHERE execution_id = 'QID1430';
GO