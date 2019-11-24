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
-- Credits:		https://docs.microsoft.com/en-us/sql/dma/dma-consolidatereports
------------------------------------------------------------------------
USE master;
GO

-- Create test database
DROP DATABASE IF EXISTS EstateInventory;
CREATE DATABASE EstateInventory;
GO

USE EstateInventory;
GO

DROP TABLE IF EXISTS dbo.DatabaseInventory;
CREATE TABLE dbo.DatabaseInventory (
	ServerName		sysname	not null
,	InstanceName	sysname	not null
,	DatabaseName	sysname	not null
,	AssessmentFlag	bit		not null

,	CONSTRAINT	PK_DatabaseInventory
	PRIMARY KEY	(ServerName, InstanceName, DatabaseName)
);
GO

INSERT dbo.DatabaseInventory
VALUES
	('localhost', 'MSSQLSERVER', 'AdventureWorks2008R2', 1)
,	('localhost', 'MSSQLSERVER', 'AdventureWorksLT2008R2', 1)
,	('localhost', 'MSSQLSERVER', 'AdventureWorks2012', 1)
,	('localhost', 'MSSQLSERVER', 'AdventureWorksLT2012', 1)
,	('localhost', 'MSSQLSERVER', 'Pubs', 1)
,	('localhost', 'MSSQLSERVER', 'Northwind', 1);
GO
