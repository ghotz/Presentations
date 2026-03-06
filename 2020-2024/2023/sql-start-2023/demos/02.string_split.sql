------------------------------------------------------------------------
-- STRING_SPLIT()
------------------------------------------------------------------------

-- Simple example with variable in SQL Server 2016
DECLARE @tags NVARCHAR(max) = 'clothing,road,,touring,bike';

SELECT	[value]
FROM	STRING_SPLIT(@tags, N',')
WHERE	RTRIM([value]) <> N'';  
GO

-- SQL Server 2022 adds argument to emit ordinal column
DECLARE @tags NVARCHAR(max) = 'clothing,road,,touring,bike';

SELECT	[value], [ordinal]
FROM	STRING_SPLIT(@tags, N',', 1)
WHERE	RTRIM([value]) <> N''
ORDER BY
		[ordinal];	-- order not guaranteed
GO

-- enable argument supports only constants... (no vars, no cols)
DECLARE @tags NVARCHAR(max) = 'clothing,road,,touring,bike';
DECLARE	@enable bit = 1;

SELECT	[value], [ordinal]
FROM	STRING_SPLIT(@tags, N',', @enable)
WHERE	RTRIM([value]) <> N'';
GO