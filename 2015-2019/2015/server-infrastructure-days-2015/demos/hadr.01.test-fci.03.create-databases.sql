------------------------------------------------------------------------
--	Description:	Create a couple of databases just for testing
------------------------------------------------------------------------
--	Copyright (c) 2015 Gianluca Hotz
--	Permission is hereby granted, free of charge, to any person
--	obtaining a copy of this software and associated documentation files
--	(the "Software"), to deal in the Software without restriction,
--	including without limitation the rights to use, copy, modify, merge,
--	publish, distribute, sublicense, and/or sell copies of the Software,
--	and to permit persons to whom the Software is furnished to do so,
--	subject to the following conditions:
--	The above copyright notice and this permission notice shall be
--	included in all copies or substantial portions of the Software.
--	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
--	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
--	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
--	NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
--	BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
--	ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
--	CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--	SOFTWARE.
------------------------------------------------------------------------
USE master;
GO

IF DB_ID('AGDB01') IS NOT NULL
	DROP DATABASE AGDB01;
GO
CREATE DATABASE AGDB01;
GO
IF DB_ID('AGDB02') IS NOT NULL
	DROP DATABASE AGDB02;
GO
CREATE DATABASE AGDB02;
GO

CREATE TABLE AGDB01.dbo.T1 (F1 int not null PRIMARY KEY);
GO
INSERT	AGDB01.dbo.T1
VALUES	(1), (2), (3), (4), (5);
GO
CREATE TABLE AGDB02.dbo.T2 (F1 int not null PRIMARY KEY);
GO
INSERT	AGDB02.dbo.T2
VALUES	(1), (2), (3), (4), (5);
GO