------------------------------------------------------------------------
-- Copyright:   2018 Gianluca Hotz
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
--              
--              The above copyright notice and this permission notice
--              shall be included in all copies or substantial portions
--              of the Software.
--              
--              THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
--              ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
--              LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
--              FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
--              EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
--              FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
--              AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--              OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
--              OTHER DEALINGS IN THE SOFTWARE.
-- Credits:     Herbert Albert
------------------------------------------------------------------------

--CREATE DATABASE

USE master

IF EXISTS(SELECT * FROM sys.databases 
			WHERE name = 'testdb')
		DROP DATABASE testdb 

CREATE DATABASE testdb
GO

use testdb
GO

CREATE TABLE TABLE1
	(id int IDENTITY(1,1) PRIMARY KEY ,
	 col1 int,
	 col2 int,
	 col3 varchar(200))
	 

CREATE TABLE TABLE2
	(id int IDENTITY(1,1) PRIMARY KEY ,
	 col1 int,
	 col2 int,
	 col3 varchar(200))	 
	 
GO
SET NOCOUNT ON 

DECLARE @x int = 1
WHILE @x <=1000
	BEGIN
	INSERT INTO TABLE1 (col1,col2,col3) VALUES(@x,@x,REPLICATE('A',200))
	INSERT INTO TABLE2 (col1,col2,col3) VALUES(@x,@x,REPLICATE('A',200))
	SET @x = @x +1
	END
 
CREATE INDEX idx_TABLE1_col1 ON TABLE1(col1)	 
CREATE INDEX idx_TABLE2_col1 ON TABLE2(col1)
GO