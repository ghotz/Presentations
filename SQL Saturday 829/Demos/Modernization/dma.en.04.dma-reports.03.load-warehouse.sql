-- Step 1 - cleans object types. (this should be a temp step until tool is fixed)
UPDATE	dmareporting..reportdata
SET		ImpactedObjectType = 'Database Options'
WHERE	ImpactedObjectType = 'DatabaseOptions'


-- Step 2 - Capture any missing rules
INSERT INTO DMAWarehouse..dimRules (RuleID, Title, Impact, Recommendation, MoreInfo, ChangeCategory)
SELECT	DISTINCT rd.Ruleid
		, rd.Title
		, REPLACE(REPLACE(rd.Impact,'<p>',''),'</p>','') AS Impact
		, rd.Recommendation
		, rd.MoreInfo
		, rd.ChangeCategory
FROM	DMAReporting..ReportData rd
LEFT JOIN DMAWarehouse..dimRules dr
	ON	rd.RuleId = dr.RuleID
	AND rd.Title = dr.Title
WHERE	dr.RuleID IS NULL

-- Capture any missing object types
INSERT INTO DMAWarehouse..dimObjectType (ObjectType)
SELECT	DISTINCT rd.ImpactedObjectType 
FROM	DMAReporting..ReportData rd
LEFT JOIN DMAWarehouse..dimObjectType ot
	ON	rd.ImpactedObjectType = ot.ObjectType
WHERE	ot.ObjectType IS NULL


-- Step 3 - Run select statement first to ensure no NULL keys (except dbowner which is expected to be null at this point).  Once happy run the INSERT
INSERT INTO DMAWarehouse..FactAssessment(DateKey, StatusKey, SourceCompatKey, TargetCompatKey, Categorykey, SeverityKey, ChangeCategorykey, RulesKey, AssessmentTargetKey, ObjectTypeKey, DBOwnerKey, InstanceName, DatabaseName, SizeMB, ImpactedObjectName, ImpactDetail, AssessmentName, AssessmentNumber)
SELECT  dd.DateKey AS "DateKey"
		,ds.StatusKey AS "StatusKey"
		,sc.SourceCompatKey AS "SourceCompatKey"
		,tc.TargetCompatKey AS "TargetCompatKey"
		,dc.CategoryKey AS "CategoryKey"
		,dsev.SeverityKey AS "SeverityKey"
		,dcc.ChangeCategoryKey AS "ChangeCategoryKey"
		,dr.RulesKey AS "RulesKey"
		,AssessmentTargetKey AS "AssessmentTargetKey"
		,ot.ObjectTypeKey AS "ObjectTypeKey"
		,dbo.DBOwnerKey AS "DBOwnerKey"
		,dma_rd.InstanceName AS "InstanceName"
		,[Name] AS "DatabaseName"
		,REPLACE(SizeMB, ',', '.') AS "SizeMB"
		,COALESCE(ImpactedObjectName, 'NA') AS "ImpactedObjectName"
		,COALESCE(ImpactDetail, 'NA') AS "ImpactDetail"
		,AssessmentName
		,AssessmentNumber
FROM dmareporting..reportdata dma_rd
LEFT JOIN DMAWarehouse..dimDate dd
	ON CONVERT(CHAR(8),dma_rd.ImportDate,112) = dd.[Date] 
LEFT JOIN DMAWarehouse..dimStatus ds
	ON dma_rd.[Status] = ds.[Status]
LEFT JOIN DMAWarehouse..dimSourceCompatibility sc
	ON dma_rd.SourceCompatibilityLevel = sc.SourceCompatibilityLevel
LEFT JOIN DMAWarehouse..dimTargetCompatibility tc
	ON dma_rd.TargetCompatibilityLevel = tc.TargetCompatibilityLevel
LEFT JOIN DMAWarehouse..dimCategory dc
	ON dma_rd.Category = dc.Category
LEFT JOIN DMAWarehouse..dimSeverity dsev
	ON dma_rd.Severity = dsev.Severity
LEFT JOIN DMAWarehouse..dimRules dr
	ON dma_rd.RuleId = dr.RuleID
	AND dma_rd.title = dr.Title -- there is a ruleid being used for 2 different titles
LEFT JOIN DMAWarehouse..dimAssessmentTarget ast
	ON dma_rd.AssessmentTarget = ast.AssessmentTarget
LEFT JOIN DMAWarehouse..dimChangeCategory dcc
	ON dma_rd.ChangeCategory = dcc.ChangeCategory
LEFT JOIN DMAWarehouse..dimObjectType ot
	ON CASE WHEN dma_rd.ImpactedObjectType IS NULL OR dma_rd.ImpactedObjectType = '' THEN 'NA' ELSE ImpactedObjectType END = ot.ObjectType
LEFT JOIN DMAWarehouse..dimDBOwner dbo
	ON dma_rd.InstanceName = dbo.InstanceName
	AND dma_rd.Name = dbo.DatabaseName
where IsLoaded = 0


-- Step 4 - update database owners

-- Populate database owners
-- Repeat for every instance / database
INSERT INTO DMAWarehouse..dimDBOwner (InstanceName, DatabaseName, DBOwner)
VALUES ('ExampleInstance', 'ExampleDatabase', 'ExampleOwner')

-- Once DBOwner dimension is populated update factassessment table
UPDATE	fa
SET		fa.DBOwnerKey = db.DBOwnerKey
FROM	DMAWarehouse..FactAssessment fa
JOIN	DMAWarehouse..dimDBOwner db
	ON	fa.InstanceName = db.InstanceName
	AND fa.DatabaseName = db.DatabaseName;