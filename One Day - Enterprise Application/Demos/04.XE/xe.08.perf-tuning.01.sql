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
-- Credits:		Itzik Ben-Gan (SolidQ), Herbert Albert (SolidQ)
------------------------------------------------------------------------

------------------------------------------------------------------------
--	Basato sul seguente articolo:
--	http://www.solidq.com/sqj/Pages/Relational/Tracing-Query-Performance-with-Extended-Events.aspx
--	Lo script per creare il database di test si trova al seguente link
--	http://tsql.solidq.com/books/source_code/Performance.txt
------------------------------------------------------------------------
USE Performance;
GO

------------------------------------------------------------------------
--	Eliminiamo il clustered index per ottenere artificialmente delle
--	query poco performanti
------------------------------------------------------------------------
DROP INDEX idx_cl_od ON dbo.Orders;
GO

------------------------------------------------------------------------
--	Creazione sessione XE
------------------------------------------------------------------------
DECLARE	@DatabaseID nvarchar(10) = CAST(DB_ID() AS nvarchar(10));
DECLARE	@SessiomStmt nvarchar(MAX) = N'
CREATE EVENT SESSION [query_performance] ON SERVER
ADD EVENT sqlserver.sp_statement_completed(
    ACTION(sqlserver.query_hash)
    WHERE sqlserver.database_id = ' + @DatabaseID + ' AND sqlserver.query_hash <> 0),
ADD EVENT sqlserver.sql_statement_completed(
    ACTION(sqlserver.query_hash)
    WHERE sqlserver.database_id = ' + @DatabaseID + ' AND sqlserver.query_hash <> 0)
ADD TARGET package0.event_file(SET filename = N''C:\temp\xevents\query_performance.xel'');
';
EXEC (@SessiomStmt);
GO

--	Start della sessione
ALTER EVENT SESSION [query_performance] ON SERVER STATE=START;
GO

------------------------------------------------------------------------
--	xe.08.perf-tuning.02.queries.sql
------------------------------------------------------------------------

-- Stop della sessione
ALTER EVENT SESSION [query_performance] ON SERVER STATE=STOP;
GO

------------------------------------------------------------------------
--	Shredding degli eventi
------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Events') IS NOT NULL DROP TABLE #Events;
IF OBJECT_ID('tempdb..#Queries') IS NOT NULL DROP TABLE #Queries;
GO

SELECT	CAST(event_data AS XML) AS event_data_XML
INTO	#Events
FROM	sys.fn_xe_file_target_read_file('C:\temp\xevents\query_performance*.xel', null, null, null) AS F;
GO

SELECT
  event_data_XML.value ('(/event/action[@name=''query_hash''    ]/value)[1]', 'BINARY(8)'     ) AS query_hash,
  event_data_XML.value ('(/event/data  [@name=''duration''      ]/value)[1]', 'BIGINT'        ) AS duration,
  event_data_XML.value ('(/event/data  [@name=''cpu_time''      ]/value)[1]', 'BIGINT'        ) AS cpu_time,
  event_data_XML.value ('(/event/data  [@name=''physical_reads'']/value)[1]', 'BIGINT'        ) AS physical_reads,
  event_data_XML.value ('(/event/data  [@name=''logical_reads'' ]/value)[1]', 'BIGINT'        ) AS logical_reads,
  event_data_XML.value ('(/event/data  [@name=''writes''        ]/value)[1]', 'BIGINT'        ) AS writes,
  event_data_XML.value ('(/event/data  [@name=''row_count''     ]/value)[1]', 'BIGINT'        ) AS row_count,
  event_data_XML.value ('(/event/data  [@name=''statement''     ]/value)[1]', 'NVARCHAR(4000)') AS statement
INTO	#Queries
FROM	#Events;
GO

CREATE CLUSTERED INDEX idx_cl_query_hash ON #Queries(query_hash);
GO

------------------------------------------------------------------------
--	Analisi
------------------------------------------------------------------------
--	Raggruppamento per hash della query e calcolo percentuale "running"
SELECT query_hash,
  COUNT(*) AS num_queries,
  SUM(logical_reads) AS sum_logical_reads,
  CAST(100.0 * SUM(logical_reads)
             / SUM(SUM(logical_reads)) OVER() AS NUMERIC(5, 2)) AS pct,
  CAST(100.0 * SUM(SUM(logical_reads)) OVER(ORDER BY SUM(logical_reads) DESC
                                            ROWS UNBOUNDED PRECEDING)
             / SUM(SUM(logical_reads)) OVER()
       AS NUMERIC(5, 2)) AS running_pct
FROM #Queries
GROUP BY query_hash
ORDER BY sum_logical_reads DESC;
GO

--	Filtro per percentuale  e recupero un esempio della query
WITH QueryHashTotals AS
(
  SELECT query_hash,
    COUNT(*) AS num_queries,
    SUM(logical_reads) AS sum_logical_reads
  FROM #Queries
  GROUP BY query_hash
),
RunningTotals AS
(
  SELECT query_hash, num_queries, sum_logical_reads,
    CAST(100. * sum_logical_reads
              / SUM(sum_logical_reads) OVER()
         AS NUMERIC(5, 2)) AS pct,
    CAST(100. * SUM(sum_logical_reads) OVER(ORDER BY sum_logical_reads DESC
                                             ROWS UNBOUNDED PRECEDING)
              / SUM(sum_logical_reads) OVER()
         AS NUMERIC(5, 2)) AS running_pct
  FROM QueryHashTotals
)
SELECT RT.*, (SELECT TOP (1) statement
              FROM #Queries AS Q
              WHERE Q.query_hash = RT.query_hash) AS sample_statement
FROM RunningTotals AS RT
WHERE running_pct - pct < 80.00
ORDER BY sum_logical_reads DESC;

--	Elimina la sessione
DROP EVENT SESSION [query_performance] ON SERVER;
GO

------------------------------------------------------------------------
--	Se le query si trovano in cache, possiamo cercarle direttamente
------------------------------------------------------------------------

WITH RunningTotals AS
(
  SELECT
    query_hash,
    SUM(execution_count) AS num_queries,
    SUM(total_logical_reads) AS sum_logical_reads,
    CAST(100. * SUM(total_logical_reads)
              / SUM(SUM(total_logical_reads)) OVER()
          AS NUMERIC(5, 2)) AS pct,
    CAST(100. * SUM(SUM(total_logical_reads)) OVER(ORDER BY SUM(total_logical_reads) DESC
                                              ROWS UNBOUNDED PRECEDING)
              / SUM(SUM(total_logical_reads)) OVER()
          AS NUMERIC(5, 2)) AS running_pct
  FROM sys.dm_exec_query_stats AS QS
    CROSS APPLY sys.dm_exec_query_plan(QS.plan_handle) AS QP
  WHERE QS.query_hash <> 0x
    AND QP.dbid = DB_ID('Performance')
  GROUP BY query_hash
)
SELECT RT.*,
  (SELECT TOP (1)
     SUBSTRING(ST.text, (QS.statement_start_offset/2) + 1,
             ((CASE statement_end_offset
                WHEN -1 THEN DATALENGTH(ST.text)
                ELSE QS.statement_end_offset END
                    - QS.statement_start_offset)/2) + 1
           )
   FROM sys.dm_exec_query_stats AS QS
     CROSS APPLY sys.dm_exec_sql_text(QS.sql_handle) AS ST
   WHERE QS.query_hash = RT.query_hash) AS sample_statement
FROM RunningTotals AS RT
WHERE running_pct - pct < 80.00
ORDER BY sum_logical_reads DESC;
