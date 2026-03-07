------------------------------------------------------------------------
--	TPC-H Simple Query
------------------------------------------------------------------------
USE [TPCH-2_16_0];
GO
SELECT	
    sum(l_extendedprice * l_discount) as revenue
FROM 		
    lineitem
WHERE 
    l_discount between 0.04 - 0.01 and 0.04 + 0.01 and
    l_quantity < 25;
GO 5