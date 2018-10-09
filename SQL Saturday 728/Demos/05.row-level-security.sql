------------------------------------------------------------------------
-- Script:		row-level-security
-- Copyright:	2017 Gianluca Hotz
-- License:		MIT License
-- Credits:
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
-- Warning: the original clinic.bacpac contains the two users
-- alice@contoso.com and rachel@contoso.com with an unknown password
-- (the one specified in the demo docs don't work) so instead just
-- CREATE two new users named nurse1@contoso.com and nurse2@contoso.com
-- in the web site and run the following
UPDATE	Clinic.dbo.ApplicationUserPatients
SET	ApplicationUser_Id = (
	SELECT	Id
	FROM	Clinic.dbo.AspNetUsers
	WHERE	Email = 'nurse1@contoso.com'
)
WHERE	ApplicationUser_Id = '2ba087ec-d8c3-4955-9a9d-c6719dc29ec2';
UPDATE	Clinic.dbo.ApplicationUserPatients
SET	ApplicationUser_Id = (
	SELECT	Id
	FROM	Clinic.dbo.AspNetUsers
	WHERE	Email = 'nurse2@contoso.com'
)
WHERE	ApplicationUser_Id = '9606e906-6d94-4fa7-a881-a6efceeaa232';
GO

-- Reset the demo from tsql-scripts/Enable-RLS.sql
USE Clinic;
GO
DROP SECURITY POLICY IF EXISTS [Security].patientSecurityPolicy;
DROP FUNCTION IF EXISTS [Security].patientAccessPredicate;
DROP SCHEMA IF EXISTS [Security];
GO

------------------------------------------------------------------------
--	Step 2: observe esisting data
------------------------------------------------------------------------
-- From tsql-scripts/Enable-RLS.sql
SELECT * FROM Clinic.dbo.Patients;
SELECT * FROM Clinic.dbo.Visits;
GO

-- This table will be used to map specifically which ASP NET Users
-- have permisions to see which Patients
SELECT * FROM Clinic.dbo.ApplicationUserPatients;
GO

------------------------------------------------------------------------
--	Step 3: create schema and Row Level Security Objects
------------------------------------------------------------------------
-- From tsql-scripts/Enable-RLS.sql
CREATE SCHEMA [Security];
GO

-- This is the predicate function that will determine hich users can
-- access which rows based on the previous mapping table
CREATE FUNCTION [Security].patientAccessPredicate(@PatientID int)
	RETURNS TABLE
	WITH SCHEMABINDING
AS
	RETURN SELECT 1 AS isAccessible
	FROM dbo.ApplicationUserPatients
	WHERE 
	(	-- application users can access only patients assigned to them
		Patient_PatientID = @PatientID
		AND ApplicationUser_Id = CAST(SESSION_CONTEXT(N'UserId') AS nvarchar(128)) 
	)
	OR 
	(	-- DBAs can access all patients
		IS_MEMBER('db_owner') = 1
	);
GO

-- This is the security policy that adds the security predicate to Patients and Visits
-- Filter predicates filter out patients who shouldn't be accessible by the current user
-- Block predicates prevent the current user from inserting any patients who aren't mapped to them
CREATE SECURITY POLICY [Security].patientSecurityPolicy
	ADD FILTER PREDICATE [Security].patientAccessPredicate(PatientID) ON dbo.Patients,
	ADD BLOCK PREDICATE [Security].patientAccessPredicate(PatientID) ON dbo.Patients,
	ADD FILTER PREDICATE [Security].patientAccessPredicate(PatientID) ON dbo.Visits,
	ADD BLOCK PREDICATE [Security].patientAccessPredicate(PatientID) ON dbo.Visits;
GO

------------------------------------------------------------------------
--	Step 4: run Web Application and switch between users
--	Rachel@contoso.com/Password1! & alice@contoso.com/Password1!
------------------------------------------------------------------------

------------------------------------------------------------------------
--	Step 5: show additional context in SSMS
------------------------------------------------------------------------

-- We can still access data because the login is sysadmin and thus db_owner
SELECT * FROM Clinic.dbo.Patients;
SELECT * FROM Clinic.dbo.Visits;
GO

-- Let's try with the web app user
EXECUTE AS USER = 'ContosoClinicApplication';
GO
SELECT * FROM Clinic.dbo.Patients;
SELECT * FROM Clinic.dbo.Visits;
GO
REVERT;
GO

-- However the web app SESSION_CONTEXT so let's try seting it
-- EXEC sp_set_session_context 'UserId', '2ba087ec-d8c3-4955-9a9d-c6719dc29ec2';
-- SELECT * FROM Clinic.dbo.ApplicationUserPatients;
EXEC sp_set_session_context 'UserId', '0d1704f2-21b9-4aea-82e5-456960751e9a';
GO
EXECUTE AS USER = 'ContosoClinicApplication';
GO
SELECT * FROM Clinic.dbo.Patients;
SELECT * FROM Clinic.dbo.Visits;
GO
REVERT;
GO
EXEC sp_set_session_context 'UserId', NULL;
GO