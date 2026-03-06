USE Clinic;
GO

-- check current data
SELECT * FROM dbo.Visits;
GO

-- insert a new row
INSERT	dbo.Visits ([PatientID], [Date], [Reason], [Treatment])
VALUES	(1, GETDATE(), N'Headache', N'Another nap');
GO

-- delete the newly inserted row
DELETE	dbo.Visits
WHERE	VisitID = 3;
GO

-- cleanup
DBCC CHECKIDENT(Visits, RESEED, 2);
GO