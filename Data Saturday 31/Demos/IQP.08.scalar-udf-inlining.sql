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
-- Demo: Scalar UDF inlining
------------------------------------------------------------------------
USE WideWorldImportersDW;
GO

ALTER DATABASE SCOPED CONFIGURATION 
CLEAR PROCEDURE_CACHE;
GO

CREATE OR ALTER FUNCTION
	dbo.customer_category(@CustomerKey INT) 
RETURNS CHAR(10) AS
BEGIN
	DECLARE	@total_amount DECIMAL(18,2);
	DECLARE	@category CHAR(10);

	SELECT	@total_amount = SUM([Total Including Tax]) 
	FROM	[Fact].[OrderHistory]
	WHERE	[Customer Key] = @CustomerKey;

	IF @total_amount < 500000
		SET @category = 'REGULAR';
	ELSE IF @total_amount < 1000000
		SET @category = 'GOLD';
	ELSE 
		SET @category = 'PLATINUM';

	RETURN @category;
END
GO

-- Let's change to 2019 beaviour  (by default scalar UDF automatic inlining is on)
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 150;
GO

-- Before (show actual query execution plan for legacy behavior)
SELECT TOP 200
		[Customer Key], [Customer],
       dbo.customer_category([Customer Key]) AS [Discount Price]
FROM [Dimension].[Customer]
ORDER BY [Customer Key]
OPTION (RECOMPILE, USE HINT('DISABLE_TSQL_SCALAR_UDF_INLINING'));
-- After (show actual query execution plan for Scalar UDF Inlining)
SELECT TOP 200
		[Customer Key], [Customer],
       dbo.customer_category([Customer Key]) AS [Discount Price]
FROM [Dimension].[Customer]
ORDER BY [Customer Key]
OPTION (RECOMPILE);
