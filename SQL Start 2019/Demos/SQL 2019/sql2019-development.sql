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

------------------------------------------------------------------------
-- Truncation error messages
-- https://support.microsoft.com/en-us/help/4468101
------------------------------------------------------------------------

-- problem with the current error message
SELECT	*
FROM	sys.messages
WHERE	message_id = 8152 AND language_id = 1033;
GO

-- "String or binary data would be truncated."
-- What? Where?

-- SQL Server 2019 introduces table/column name and value
SELECT	*
FROM	sys.messages
WHERE	message_id = 2628 AND language_id = 1033;
GO

-- "String or binary data would be truncated in table '%.*ls', column '%.*ls'. Truncated value: '%.*ls'."

-- Practical example
USE tempdb;
GO
DROP TABLE IF EXISTS dbo.T1;
CREATE TABLE dbo.T1 (S1 VARCHAR(10));
GO

-- Error message is useless in many cases
INSERT INTO dbo.T1
VALUES ('Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.');
GO

-- Needs Trace Flag 460 to opt-in in SQL Server 2019 CTP2.2
DBCC TRACEON(460);
GO

-- New error message more usefull
INSERT INTO dbo.T1
VALUES ('Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.');
GO

-- Cleanup
DBCC TRACEOFF(460);
GO

------------------------------------------------------------------------
-- Java integration
-- https://docs.microsoft.com/en-us/sql/advanced-analytics/java/java-first-sample
------------------------------------------------------------------------ 
USE tempdb;
GO
DROP TABLE IF exists reviews;
GO
CREATE TABLE reviews(
	id int NOT NULL,
	"text" nvarchar(30) NOT NULL)

INSERT INTO reviews(id, "text") VALUES (1, 'AAA BBB CCC DDD EEE FFF')
INSERT INTO reviews(id, "text") VALUES (2, 'GGG HHH III JJJ KKK LLL')
INSERT INTO reviews(id, "text") VALUES (3, 'MMM NNN OOO PPP QQQ RRR')
GO

-- Be sure to have compiled the Java classes
-- javac Ngram.java InputRow.java OutputRow.java

-- Also that external scripts are enabled
 --EXEC sp_configure 'external scripts enabled', 1
 --RECONFIGURE WITH OVERRIDE

DECLARE @myClassPath nvarchar(50)
DECLARE @n int 

--This is where you store your classes or jars.
--Update this to your own classpath
SET @myClassPath = N'C:\Demos'

--This is the size of the ngram
SET @n = 3

EXEC sp_execute_external_script
  @language = N'Java'
, @script = N'pkg.Ngram.getNGrams'
, @input_data_1 = N'SELECT id, text FROM reviews'
, @parallel = 0
, @params = N'@CLASSPATH nvarchar(30), @param1 INT'
, @CLASSPATH = @myClassPath
, @param1 = @n
with result sets ((ID int, ngram varchar(20)))
GO

-- alternative with jar files
-- jar -cf ngram.jar *.class

--DROP EXTERNAL LIBRARY ngram;
--GO
--CREATE EXTERNAL LIBRARY ngram
--FROM (CONTENT = 'C:\Demos\ngram.jar') 
--WITH (LANGUAGE = 'Java'); 
--GO

--DECLARE @n int
--SET @n = 3

--EXEC sp_execute_external_script
--  @language = N'Java'
--, @script = N'pkg.ngram.getNGrams'
--, @input_data_1 = N'SELECT id, text FROM reviews'
--, @parallel = 0
--, @params = N'@param1 INT'
--, @param1 = @n
--with result sets ((ID int, ngram varchar(20)))
--GO