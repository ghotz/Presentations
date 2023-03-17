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
-- Demo: Interleaved Execution
------------------------------------------------------------------------
USE WideWorldImportersDW;
GO

-- multi-statement table-valued function
CREATE OR ALTER FUNCTION [Fact].[WhatIfOutlierEventQuantity](@event VARCHAR(15), @beginOrderDateKey DATE, @endOrderDateKey DATE)
RETURNS @OutlierEventQuantity TABLE (
	[Order Key] [bigint],
	[City Key] [int] NOT NULL,
	[Customer Key] [int] NOT NULL,
	[Stock Item Key] [int] NOT NULL,
	[Order Date Key] [date] NOT NULL,
	[Picked Date Key] [date] NULL,
	[Salesperson Key] [int] NOT NULL,
	[Picker Key] [int] NULL,
	[OutlierEventQuantity] [int] NOT NULL)
AS 
BEGIN

-- Valid @event values
	-- 'Mild Recession'
	-- 'Hurricane - South Atlantic'
	-- 'Hurricane - East South Central'
	-- 'Hurricane - West South Central'
	IF @event = 'Mild Recession'
    INSERT  @OutlierEventQuantity
	SELECT [o].[Order Key], [o].[City Key], [o].[Customer Key],
           [o].[Stock Item Key], [o].[Order Date Key], [o].[Picked Date Key],
           [o].[Salesperson Key], [o].[Picker Key], 
           CASE
			WHEN [o].[Quantity] > 2 THEN [o].[Quantity] * .5
			ELSE [o].[Quantity]
		   END 
	FROM [Fact].[Order] AS [o]
	INNER JOIN [Dimension].[City] AS [c]
		ON [c].[City Key] = [o].[City Key]

	IF @event = 'Hurricane - South Atlantic'
    INSERT  @OutlierEventQuantity
	SELECT [o].[Order Key], [o].[City Key], [o].[Customer Key],
           [o].[Stock Item Key], [o].[Order Date Key], [o].[Picked Date Key],
           [o].[Salesperson Key], [o].[Picker Key], 
           CASE
			WHEN [o].[Quantity] > 10 THEN [o].[Quantity] * .5
			ELSE [o].[Quantity]
		   END 
	FROM [Fact].[Order] AS [o]
	INNER JOIN [Dimension].[City] AS [c]
		ON [c].[City Key] = [o].[City Key]
	WHERE [c].[State Province] IN
	('Florida', 'Georgia', 'Maryland', 'North Carolina',
	'South Carolina', 'Virginia', 'West Virginia',
	'Delaware')
	AND [o].[Order Date Key] BETWEEN @beginOrderDateKey AND @endOrderDateKey

	IF @event = 'Hurricane - East South Central'
    INSERT  @OutlierEventQuantity
	SELECT [o].[Order Key], [o].[City Key], [o].[Customer Key],
           [o].[Stock Item Key], [o].[Order Date Key], [o].[Picked Date Key],
           [o].[Salesperson Key], [o].[Picker Key], 
           CASE
			WHEN [o].[Quantity] > 50 THEN [o].[Quantity] * .5
			ELSE [o].[Quantity]
		   END
	FROM [Fact].[Order] AS [o]
	INNER JOIN [Dimension].[City] AS [c]
		ON [c].[City Key] = [o].[City Key]
	INNER JOIN [Dimension].[Stock Item] AS [si]
	ON [si].[Stock Item Key] = [o].[Stock Item Key]
	WHERE [c].[State Province] IN
	('Alabama', 'Kentucky', 'Mississippi', 'Tennessee')
	AND [si].[Buying Package] = 'Carton'
	AND [o].[Order Date Key] BETWEEN @beginOrderDateKey AND @endOrderDateKey

	IF @event = 'Hurricane - West South Central'
    INSERT  @OutlierEventQuantity
	SELECT [o].[Order Key], [o].[City Key], [o].[Customer Key],
           [o].[Stock Item Key], [o].[Order Date Key], [o].[Picked Date Key],
           [o].[Salesperson Key], [o].[Picker Key], 
           CASE
		    WHEN [cu].[Customer] = 'Unknown' THEN 0
			WHEN [cu].[Customer] <> 'Unknown' AND
			 [o].[Quantity] > 10 THEN [o].[Quantity] * .5
			ELSE [o].[Quantity]
		   END
	FROM [Fact].[Order] AS [o]
	INNER JOIN [Dimension].[City] AS [c]
		ON [c].[City Key] = [o].[City Key]
	INNER JOIN [Dimension].[Customer] AS [cu]
	ON [cu].[Customer Key] = [o].[Customer Key]
	WHERE [c].[State Province] IN
	('Arkansas', 'Louisiana', 'Oklahoma', 'Texas')
	AND [o].[Order Date Key] BETWEEN @beginOrderDateKey AND @endOrderDateKey

    RETURN
END
GO

-- let's see standard behaviour before 2017
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 130;
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

-- explore execution plan: 100 rows estimated from TVF, 231417 returned, spills (with compatibility level 130)
SELECT  [fo].[Order Key], [fo].[Description], [fo].[Package], [fo].[Quantity], [foo].[OutlierEventQuantity]
FROM    [Fact].[Order] AS [fo]
INNER JOIN [Fact].[WhatIfOutlierEventQuantity]('Mild Recession','1-01-2013','10-15-2014') AS [foo] 
							ON [fo].[Order Key] = [foo].[Order Key]
                            AND [fo].[City Key] = [foo].[City Key]
                            AND [fo].[Customer Key] = [foo].[Customer Key]
                            AND [fo].[Stock Item Key] = [foo].[Stock Item Key]
                            AND [fo].[Order Date Key] = [foo].[Order Date Key]
                            AND [fo].[Picked Date Key] = [foo].[Picked Date Key]
                            AND [fo].[Salesperson Key] = [foo].[Salesperson Key]
                            AND [fo].[Picker Key] = [foo].[Picker Key]
INNER JOIN [Dimension].[Stock Item] AS [si] 
ON [fo].[Stock Item Key] = [si].[Stock Item Key]
WHERE   [si].[Lead Time Days] > 0 AND [fo].[Quantity] > 50;
GO

ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 140;
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

-- explore execution plan: 231417 rows estimated and returned from TVF, no spills
SELECT  [fo].[Order Key], [fo].[Description], [fo].[Package], [fo].[Quantity], [foo].[OutlierEventQuantity]
FROM    [Fact].[Order] AS [fo]
INNER JOIN [Fact].[WhatIfOutlierEventQuantity]('Mild Recession','1-01-2013','10-15-2014') AS [foo] 
							ON [fo].[Order Key] = [foo].[Order Key]
                            AND [fo].[City Key] = [foo].[City Key]
                            AND [fo].[Customer Key] = [foo].[Customer Key]
                            AND [fo].[Stock Item Key] = [foo].[Stock Item Key]
                            AND [fo].[Order Date Key] = [foo].[Order Date Key]
                            AND [fo].[Picked Date Key] = [foo].[Picked Date Key]
                            AND [fo].[Salesperson Key] = [foo].[Salesperson Key]
                            AND [fo].[Picker Key] = [foo].[Picker Key]
INNER JOIN [Dimension].[Stock Item] AS [si] 
ON [fo].[Stock Item Key] = [si].[Stock Item Key]
WHERE   [si].[Lead Time Days] > 0 AND [fo].[Quantity] > 50;
GO

-- The functionality can be disabled independently from the compatibility level
-- ALTER DATABASE SCOPED CONFIGURATION SET INTERLEAVED_EXECUTION_TVF = ON;
