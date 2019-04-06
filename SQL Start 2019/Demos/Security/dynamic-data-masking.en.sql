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
-- Credits:     https://github.com/Microsoft/sql-server-samples
------------------------------------------------------------------------
------------------------------------------------------------------------
--	General demo setup
--
--	Clone SQL Server 2016 Repository from
--	https://github.com/Microsoft/sql-server-samples
--
--	The step-by-step instructions for the RLS demo are available at
--	https://github.com/Microsoft/sql-server-samples/tree/master/samples/features/security/contoso-clinic
--
--	Local repository
--	C:\Users\Gianluca\Source\Repos\sql-server-samples\samples\features\security\contoso-clinic
------------------------------------------------------------------------

------------------------------------------------------------------------
--	Step 1: import Clinic *.bacpac or continue from previous demo
------------------------------------------------------------------------
-- Reset the demo from tsql-scripts/Enable-DDM.sql
USE Clinic;
GO
ALTER TABLE Patients ALTER COLUMN LastName DROP MASKED;
ALTER TABLE Patients ALTER COLUMN MiddleName DROP MASKED;
ALTER TABLE Patients ALTER COLUMN StreetAddress DROP MASKED;
ALTER TABLE Patients ALTER COLUMN ZipCode DROP MASKED;
GO

------------------------------------------------------------------------
--	Step 2: run Web Application with alice@contoso.com/Password1!
------------------------------------------------------------------------
-- Check Patients
SELECT * FROM Clinic.dbo.Patients;
GO

------------------------------------------------------------------------
--	Step 3: add maskS
------------------------------------------------------------------------
-- Reset the demo from tsql-scripts/Enable-DDM.sql
-- Expose only first letter of last name
ALTER TABLE Patients ALTER COLUMN LastName ADD MASKED WITH (FUNCTION = 'partial(1, "xxxx", 0)');

-- Full mask for middle initial, street address, and zip code
ALTER TABLE Patients ALTER COLUMN MiddleName ADD MASKED WITH (FUNCTION = 'default()');
ALTER TABLE Patients ALTER COLUMN StreetAddress ADD MASKED WITH (FUNCTION = 'default()');
ALTER TABLE Patients ALTER COLUMN ZipCode ADD MASKED WITH (FUNCTION = 'default()');
GO

------------------------------------------------------------------------
--	Step 4: switch to Web Application and refresh Patients
------------------------------------------------------------------------

------------------------------------------------------------------------
--	Step 5: DDM catalog
------------------------------------------------------------------------
SELECT	c.name, tbl.name as table_name, c.is_masked, c.masking_function  
FROM	sys.masked_columns AS c  
JOIN	sys.tables AS tbl
  ON	c.[object_id] = tbl.[object_id]  
WHERE	is_masked = 1;  
GO

------------------------------------------------------------------------
--	Step 6: Other mask types
------------------------------------------------------------------------
DROP TABLE IF EXISTS dbo.PatientsExtended;
CREATE TABLE dbo.PatientsExtended(
	PatientID	int				NOT NULL PRIMARY KEY
,	Email		nvarchar(256)
				MASKED WITH (FUNCTION = 'email()')
				NOT NULL 
,	Salary		money
				MASKED WITH (FUNCTION = 'random(30000, 120000)')
				NOT NULL
,	CreditCard	varchar(19)
				MASKED WITH (FUNCTION = 'partial(0,"XXXX-XXXX-XXXX-",4)')
				NOT NULL
)
GO

-- Insert some test data
INSERT	dbo.PatientsExtended VALUES (1, 'cabel@contoso.com', 60000, '1234-5678-9012-3456');
INSERT	dbo.PatientsExtended VALUES (2, 'kima@nowhere.org', 70000, '6543-2109-8765-4321');
GO

-- We can see the data becaure CONTROL on database implies ALTER ANY MASK and UNMASK
SELECT * FROM dbo.PatientsExtended
GO

-- Let's try with the web app user
EXECUTE AS USER = 'ContosoClinicApplication';
GO
SELECT * FROM dbo.PatientsExtended;
GO
REVERT;
GO

-- The user need to have proper UNMASK permission
GRANT UNMASK TO ContosoClinicApplication;
GO
EXECUTE AS USER = 'ContosoClinicApplication';
GO
SELECT * FROM dbo.PatientsExtended;
GO
REVERT;
GO
REVOKE UNMASK TO ContosoClinicApplication;
GO

------------------------------------------------------------------------
-- IMPORTANT NOTE! Storing entire Credit Card number protected only
-- by masking is not a good pratice, this is only an example and
-- should not be regarder as any kind of guidance to store sensitive
-- data
------------------------------------------------------------------------

------------------------------------------------------------------------
--	Step 7: Beware of data movement!
------------------------------------------------------------------------
DROP TABLE IF EXISTS #tmp;
EXECUTE AS USER = 'ContosoClinicApplication';
GO
SELECT PatientID, Salary, CrediCard INTO #tmp FROM dbo.PatientsExtended;
GO
REVERT;
GO
-- Data is statically masked
SELECT * FROM #tmp;
GO

------------------------------------------------------------------------
--	Step 8: Beware also of brute-force techniques
------------------------------------------------------------------------
-- value inference using range predicates and partitioning
EXECUTE AS USER = 'ContosoClinicApplication';
GO
SELECT * FROM dbo.PatientsExtended WHERE Salary BETWEEN 50000 AND 100000;
SELECT * FROM dbo.PatientsExtended WHERE Salary BETWEEN 50000 AND 75000;
SELECT * FROM dbo.PatientsExtended WHERE Salary BETWEEN 50000 AND 62500;
SELECT * FROM dbo.PatientsExtended WHERE Salary BETWEEN 50000 AND 56250;
SELECT * FROM dbo.PatientsExtended WHERE Salary BETWEEN 56250 AND 62500;
SELECT * FROM dbo.PatientsExtended WHERE Salary BETWEEN 56250 AND 59375;
SELECT * FROM dbo.PatientsExtended WHERE Salary BETWEEN 59375 AND 62500;
GO
REVERT;
GO

-- value inference using domain table
DROP FUNCTION IF EXISTS dbo.fn_numbers;
GO
CREATE FUNCTION dbo.fn_numbers(@Start AS BIGINT,@End AS BIGINT) RETURNS TABLE
AS
RETURN
  WITH
  L0   AS(SELECT 1 AS c UNION ALL SELECT 1),
  L1   AS(SELECT 1 AS c FROM L0 AS A, L0 AS B),
  L2   AS(SELECT 1 AS c FROM L1 AS A, L1 AS B),
  L3   AS(SELECT 1 AS c FROM L2 AS A, L2 AS B),
  L4   AS(SELECT 1 AS c FROM L3 AS A, L3 AS B),
  L5   AS(SELECT 1 AS c FROM L4 AS A, L4 AS B),
  Nums AS(SELECT ROW_NUMBER() OVER(ORDER BY c) AS n FROM L5)
  SELECT n FROM Nums 
  WHERE n between  @Start and @End;  
GO  

EXECUTE AS USER = 'ContosoClinicApplication';
GO
SELECT	T1.PatientID, T1.Salary AS MaskedSalary, T2.n AS Salary
FROM	dbo.PatientsExtended AS T1
JOIN	dbo.fn_numbers(50000, 100000) AS T2
  ON	FLOOR(T1.Salary) = T2.n;
GO
REVERT;
GO
