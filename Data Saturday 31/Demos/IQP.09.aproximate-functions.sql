------------------------------------------------------------------------
-- Copyright:   2022 Gianluca Hotz
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
-- Credits:     Joe Sack https://blogs.msdn.microsoft.com/sqlserverstorageengine/2018/09/24/introducing-batch-mode-on-rowstore
--                       https://github.com/joesackmsft/Conferences/tree/master/IQPDemos
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Demo APPROX_COUNT_DISTINCT
------------------------------------------------------------------------
USE WideWorldImportersDW;
GO

-- aproximate functions work also with previous compatibility levels
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 110;
GO

-- Verify that the results are not precise and that in the execution plan
-- the first one is cheaper and faster
--SELECT	D.[Calendar Year Label], APPROX_COUNT_DISTINCT(O.[Order Key])
--FROM	Fact.[Order] AS O
--JOIN	Dimension.[Date] AS D
--ON		O.[Order Date Key] = D.[Date]
--GROUP BY D.[Calendar Year Label]
--OPTION (USE HINT('DISALLOW_BATCH_MODE'), RECOMPILE); -- Isolating out BMOR

--SELECT	D.[Calendar Year Label], COUNT(DISTINCT O.[Order Key])
--FROM	Fact.[Order] AS O
--JOIN	Dimension.[Date] AS D
--ON		O.[Order Date Key] = D.[Date]
--GROUP BY D.[Calendar Year Label]
--OPTION (USE HINT('DISALLOW_BATCH_MODE'), RECOMPILE); -- Isolating out BMOR
--GO

USE WideWorldImportersDW;
GO

-- Compare execution time and distinct counts
SELECT COUNT(DISTINCT [WWI Order ID])
FROM [Fact].[OrderHistoryExtended]
OPTION (USE HINT('DISALLOW_BATCH_MODE'), RECOMPILE); -- Isolating out BMOR
GO

SELECT APPROX_COUNT_DISTINCT([WWI Order ID])
FROM [Fact].[OrderHistoryExtended]
OPTION (USE HINT('DISALLOW_BATCH_MODE'), RECOMPILE); -- Isolating out BMOR
GO

------------------------------------------------------------------------
-- Demo APPROX_PERCENTILE_DISC, APPROX_PERCENTILE_CONT
------------------------------------------------------------------------
USE WideWorldImportersDW;
GO

-- aproximate functions work also with previous compatibility levels
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 110;
GO

DROP TABLE IF EXISTS tblEmployee
GO
CREATE TABLE tblEmployee (
	EmplId INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
	DeptId INT,
	Salary int);
GO
INSERT INTO tblEmployee
VALUES (1, 31),(1, 33), (1, 18), (2, 25),(2, 35),(2, 10), (2, 10),(3,1), (3,NULL), (4,NULL), (4,NULL)
GO
SELECT DISTINCT DeptId
,	PERCENTILE_DISC(0.10) WITHIN GROUP(ORDER BY Salary)
		OVER (PARTITION BY DeptId) AS 'P10'
,	PERCENTILE_DISC(0.90) WITHIN GROUP(ORDER BY Salary)
		OVER (PARTITION BY DeptId) AS 'P90'
FROM tblEmployee;
GO
SELECT DeptId
,	APPROX_PERCENTILE_DISC(0.10) WITHIN GROUP(ORDER BY Salary) AS 'P10'
,	APPROX_PERCENTILE_DISC(0.90) WITHIN GROUP(ORDER BY Salary) AS 'P90'
FROM tblEmployee
GROUP BY DeptId;
GO
