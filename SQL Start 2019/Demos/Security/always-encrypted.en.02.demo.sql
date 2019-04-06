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
--	The step-by-step instructions for the Always Encrypted demo are available at
--	https://github.com/Microsoft/sql-server-samples/tree/master/samples/features/security/contoso-clinic
--
--	Local repository
--	C:\Users\Gianluca\Source\Repos\sql-server-samples\samples\features\security\contoso-clinic
------------------------------------------------------------------------

------------------------------------------------------------------------
--	Step 1: import Clinic *.bacpac with SSMS or clean-up everything
------------------------------------------------------------------------
-- Clean-up
USE Clinic;
GO
IF EXISTS (SELECT * FROM sys.sql_logins WHERE [name] = 'ContosoClinicApplication')
	DROP LOGIN [ContosoClinicApplication];
DROP USER IF EXISTS [ContosoClinicApplication];
GO

------------------------------------------------------------------------
--	Step 2: create users/logins and grant permissions
------------------------------------------------------------------------
-- From setup/Create-Application-Login.sql
-- Create a non-sysadmin account for the application to use
CREATE LOGIN [ContosoClinicApplication] WITH PASSWORD = 'Passw0rd1';
CREATE USER [ContosoClinicApplication] FOR LOGIN [ContosoClinicApplication];
-- Grant user permission
EXEC sp_addrolemember N'db_datareader', N'ContosoClinicApplication';
EXEC sp_addrolemember N'db_datawriter', N'ContosoClinicApplication'; 
GRANT VIEW ANY COLUMN MASTER KEY DEFINITION TO [ContosoClinicApplication];
GRANT VIEW ANY COLUMN ENCRYPTION KEY  DEFINITION TO [ContosoClinicApplication];
GO

------------------------------------------------------------------------
--	Step 3: reset web.config settings and show application
------------------------------------------------------------------------

------------------------------------------------------------------------
--	Step 4: show data in SSMS and Encrypt Data
------------------------------------------------------------------------
SELECT * FROM Clinic.dbo.Patients;
GO

-- Start "Encrypt Columns..." wizard from dbo.Patients and
-- encrypt column SSN as deterministic
-- encrypt column BirthDate as randomized
-- use Windows Certificate Store and auto generate master keys

-- Show encrypted data in SSMS
SELECT * FROM Clinic.dbo.Patients;
GO

------------------------------------------------------------------------
--	Step 6: show data in Browser and fix web application
------------------------------------------------------------------------

------------------------------------------------------------------------
--	Step 7: show keys metadata
------------------------------------------------------------------------
-- Show Security/Always Encrypted Keys in SSMS
-- Show CREATE TABLE script

--	Always Encrypted Keys DMVs 
SELECT * FROM sys.column_master_keys;
SELECT * FROM sys.column_encryption_keys;
SELECT * FROM sys.column_encryption_key_values;
GO

------------------------------------------------------------------------
--	Step 8: reconnect SSMS with Column Encryption Setting=Enabled
------------------------------------------------------------------------
-- Show ecrypted data in SSMS
SELECT * FROM Clinic.dbo.Patients;
GO

--
-- Ad-hoc queries on regular columns continue to work
SELECT * FROM Clinic.dbo.Patients WHERE FirstName = 'Catherine';
GO

-- But not on encrypted columns
SELECT * FROM Clinic.dbo.Patients WHERE SSN = '795-73-9838';
GO
DECLARE	@SSN char(11) = '795-73-9838';
SELECT * FROM Clinic.dbo.Patients WHERE SSN = @SSN
GO

-- SSMS V17 has "Parameterization for Always Encrypted" Query Options
-- that will efectively convert the calls to something similar
EXEC	sp_describe_parameter_encryption
		N'DECLARE @SSN AS CHAR (11) = @SSN_Chyper; SELECT * FROM dbo.Patients WHERE [SSN] = @SSN;'
	,	N'@SSN_Chyper char(11)';
GO

EXEC	sp_executesql
		N'DECLARE @SSN AS CHAR (11) = @SSN_Chyper; SELECT * FROM dbo.Patients WHERE [SSN] = @SSN;'
	,	N'@SSN_Chyper char(11)'
	,	@SSN_Chyper = 0x0160E909C63EE21D58A72E7C893BC9076E682A537A7B18A136F527A240C5CF9F412F51B311007AFDE7EB67CEF4F346ED62F1612FA2ACEA13B018B5A2C34E14DBBE;
GO

-- Mixing cyphertext with plaintext not supported
SELECT 'SSN:' + SSN FROM Clinic.dbo.Patients;
GO

-- In general, beware in general about operations that would require the data
-- to be decrypted/interpreted on the server e.g.
SELECT MAX(BirthDate) FROM Clinic.dbo.Patients;
GO
SELECT YEAR(BirthDate) FROM Clinic.dbo.Patients;
GO
SELECT * FROM Clinic.dbo.Patients ORDER BY BirthDate;
GO
SELECT * INTO #tmp FROM Clinic.dbo.Patients;
GO
DROP TABLE IF EXISTS Clinic.dbo.PatientsSSN;
CREATE TABLE Clinic.dbo.PatientsSSN (SSN Char(11) NOT NULL);
INSERT	Clinic.dbo.PatientsSSN (SSN)
SELECT	SSN
FROM	Clinic.dbo.Patients;
GO

-- The following works...
DROP TABLE IF EXISTS Clinic.dbo.Patients2;
SELECT * INTO Clinic.dbo.Patients2 FROM Clinic.dbo.Patients;
GO

-- ... because the destination data is encryted the same way
SELECT * FROM Clinic.dbo.Patients2;
SELECT * FROM sys.all_columns WHERE [object_id] = OBJECT_ID('dbo.Patients2');
GO

-- Indexes can be reated only on columns encypted deterministically
CREATE INDEX ix_Patients_SSN ON Clinic.dbo.Patients(SSN);
GO
-- This doesn't work
CREATE INDEX ix_Patients_BirthDate ON Clinic.dbo.Patients(BirthDate);
GO

------------------------------------------------------------------------
--	Step 8: if time permits, show parametrized call with profiler
------------------------------------------------------------------------
