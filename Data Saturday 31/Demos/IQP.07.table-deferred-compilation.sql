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
-- Demo: Table Variable Deferred Compilation
------------------------------------------------------------------------
USE WideWorldImportersDW;
GO

-- Let's see standard behaviour before 2019
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 140;
GO

-- Check in the execution plan that the row estimate
-- from the TV is 1 and that leads to an loop join
DECLARE	@Orders TABLE (
			[Order Key] INT NOT NULL
		,	Quantity INT NOT NULL);

INSERT	@Orders
SELECT	O.[Order Key], O.Quantity
FROM	Fact.[Order] AS O
WHERE	O.Quantity = 5;

SELECT	O1.[Order Key], O1.Quantity, O2.[Description]
FROM	@Orders AS O1
JOIN	Fact.[Order] AS O2
  ON	O1.[Order Key] = O2.[Order Key]
GO

-- Let's change to 2019 beaviour  (by default table variable deferred compilation is on)
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 150;
GO

-- Check in the execution plan that the row estimate
-- from the TV is correct and that leads to an hash join
DECLARE	@Orders TABLE (
			[Order Key] INT NOT NULL
		,	Quantity INT NOT NULL);

INSERT	@Orders
SELECT	O.[Order Key], O.Quantity
FROM	Fact.[Order] AS O
WHERE	O.Quantity = 5;

SELECT	O1.[Order Key], O1.Quantity, O2.[Description]
FROM	@Orders AS O1
JOIN	Fact.[Order] AS O2
  ON	O1.[Order Key] = O2.[Order Key]
GO

-- The functionality can be disabled independently from the compatibility level
-- at database level
-- ALTER DATABASE SCOPED CONFIGURATION SET DEFERRED_COMPILATION_TV = ON;
-- at query level
DECLARE	@Orders TABLE (
			[Order Key] INT NOT NULL
		,	Quantity INT NOT NULL);

INSERT	@Orders
SELECT	O.[Order Key], O.Quantity
FROM	Fact.[Order] AS O
WHERE	O.Quantity = 5;

SELECT	O1.[Order Key], O1.Quantity, O2.[Description]
FROM	@Orders AS O1
JOIN	Fact.[Order] AS O2
  ON	O1.[Order Key] = O2.[Order Key]
OPTION	(USE HINT('DISABLE_DEFERRED_COMPILATION_TV'));
GO
