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
--              This script needs to be run on the source system.
-- Credits:     https://docs.microsoft.com/en-us/sql/relational-databases/security/sql-data-discovery-and-classification
--              Aaron Bertrand https://www.mssqltips.com/sqlservertip/5715/new-command-in-sql-server-2019-add-sensitivity-classification
------------------------------------------------------------------------

------------------------------------------------------------------------
-- SQL Data Discovery & Classification (SQL 2008+, SSMS V17.5+)
------------------------------------------------------------------------
USE AdventureWorks2017;
GO

-- Classify data with SSMS

-- Check custom reporting on extended properties
SELECT
    schema_name(O.schema_id) AS schema_name,
    O.NAME AS table_name,
    C.NAME AS column_name,
    information_type,
    sensitivity_label 
FROM
    (
        SELECT
            IT.major_id,
            IT.minor_id,
            IT.information_type,
            L.sensitivity_label 
        FROM
        (
            SELECT
                major_id,
                minor_id,
                value AS information_type 
            FROM sys.extended_properties 
            WHERE NAME = 'sys_information_type_name'
        ) IT 
        FULL OUTER JOIN
        (
            SELECT
                major_id,
                minor_id,
                value AS sensitivity_label 
            FROM sys.extended_properties 
            WHERE NAME = 'sys_sensitivity_label_name'
        ) L 
        ON IT.major_id = L.major_id AND IT.minor_id = L.minor_id
    ) EP
    JOIN sys.objects O
    ON  EP.major_id = O.object_id 
    JOIN sys.columns C 
    ON  EP.major_id = C.object_id AND EP.minor_id = C.column_id

------------------------------------------------------------------------
-- SQL Server SENSITIVITY CLASSIFICATION (SQL Server 2019+)
------------------------------------------------------------------------
USE AdventureWorks2017;
GO

-- Classification via T-SQL
ADD SENSITIVITY CLASSIFICATION TO
    Person.Person.FirstName, 
    Person.Person.LastName
WITH (LABEL = 'Confidential - GDPR', INFORMATION_TYPE = 'Contact Info');

ADD SENSITIVITY CLASSIFICATION TO
    HumanResources.Employee.BirthDate
WITH (LABEL = 'Confidential - GDPR', INFORMATION_TYPE = 'Date of birth');

ADD SENSITIVITY CLASSIFICATION TO HumanResources.Employee.NationalIDNumber
WITH (LABEL = 'Highly Confidential', INFORMATION_TYPE = 'National ID');

ADD SENSITIVITY CLASSIFICATION TO HumanResources.EmployeePayHistory.Rate
WITH (LABEL = 'Highly Confidential', INFORMATION_TYPE = 'Financial');
GO

-- Verify metadata
SELECT	*
FROM	sys.sensitivity_classifications;
GO

-- Create server level audit
USE master;
GO
CREATE SERVER AUDIT GDPRAudit TO FILE (FILEPATH = 'C:\Demos\');
ALTER SERVER AUDIT GDPRAudit WITH (STATE = ON);
GO

-- Create database level audit
USE AdventureWorks2017;
GO
CREATE DATABASE AUDIT SPECIFICATION AuditEmployees
FOR SERVER AUDIT GDPRAudit
ADD (SELECT ON HumanResources.Employee BY dbo) WITH (STATE = ON);
GO

-- execute a select from the audited table
SELECT * FROM HumanResources.Employee;
GO 5

SELECT
	session_server_principal_name, event_time, [host_name]
,	[object] = [database_name] + '.' + [schema_name] + '.' + [object_name]
,	[statement]
,	data_sensitivity_information = CONVERT(xml, data_sensitivity_information)
FROM
	sys.fn_get_audit_file ('C:\Demos\GDPRAudit_*.sqlaudit', default, default)
WHERE
	action_id = 'SL'; -- SELECT
GO

-- Cleanup
ALTER DATABASE AUDIT SPECIFICATION AuditEmployees WITH (STATE = OFF);
DROP DATABASE AUDIT SPECIFICATION AuditEmployees;
GO
USE master;
GO
ALTER SERVER AUDIT GDPRAudit WITH (STATE = OFF);
DROP SERVER AUDIT GDPRAudit;
GO
USE AdventureWorks2017;
GO
DROP SENSITIVITY CLASSIFICATION FROM Person.Person.FirstName, Person.Person.LastName;
DROP SENSITIVITY CLASSIFICATION FROM HumanResources.Employee.BirthDate;
DROP SENSITIVITY CLASSIFICATION FROM HumanResources.Employee.NationalIDNumber;
DROP SENSITIVITY CLASSIFICATION FROM HumanResources.EmployeePayHistory.Rate;
GO

-- Quick conversion between extended properties based and this one
-- From https://www.mssqltips.com/sqlservertip/5715/new-command-in-sql-server-2019-add-sensitivity-classification
DECLARE @sql nvarchar(max) = N'';

SELECT @sql += N'ADD SENSITIVITY CLASSIFICATION TO ' 
  + QUOTENAME(s.name) + QUOTENAME(o.name) + QUOTENAME(c.name)
  + ' WITH (LABEL = ''' 
  + REPLACE(CONVERT(nvarchar(256), l.value), '''', '''''') 
  + ''', INFORMATION_TYPE = ''' 
  + REPLACE(CONVERT(nvarchar(256), t.value), '''', '''''') 
  + ''');' + CHAR(13) + CHAR(10)
FROM sys.extended_properties AS t
INNER JOIN sys.extended_properties AS l
ON t.class = l.class AND t.major_id = l.major_id AND t.minor_id = l.minor_id
INNER JOIN sys.objects AS o
ON t.major_id = o.[object_id]
INNER JOIN sys.columns AS c
ON t.major_id = c.[object_id]
AND t.minor_id = c.column_id
INNER JOIN sys.schemas AS s
ON o.[schema_id] = s.[schema_id]
WHERE t.name = N'sys_information_type_name'
  AND l.name = N'sys_sensitivity_label_name';

PRINT @sql;