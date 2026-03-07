------------------------------------------------------------------------
--	Script:			xperf.02.query.sql
--	Description:	Query per esempio WPA per I/O
--	Author:			Gianluca Hotz (SolidQ)
--	Copyright:		Attribution-NonCommercial-ShareAlike 3.0
------------------------------------------------------------------------

--
--	Per maggiori informazioni
--	http://blogs.msdn.com/b/sql_pfe_blog/archive/2013/04/23/identifying-cause-of-sql-server-io-bottleneck-using-xperf.aspx
--

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
