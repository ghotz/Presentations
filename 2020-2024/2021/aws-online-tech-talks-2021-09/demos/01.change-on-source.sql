-- check that Title is NULL
SELECT	* 
FROM	Person.Person
WHERE	BusinessEntityID = 1;
GO

-- switch to target to check

-- update Title to Mr.
UPDATE	Person.Person
SET		Title = 'Mr.'
WHERE	BusinessEntityID = 1;
GO
-- check dms task and then target

-- update Title to original NULL value
UPDATE	Person.Person
SET		Title = NULL
WHERE	BusinessEntityID = 1
GO

-- add a column to table
ALTER TABLE Person.Person
ADD TestReplica int NULL;
GO

-- check dms task and then target

-- remove the column from the table
ALTER TABLE Person.Person
DROP COLUMN TestReplica;
GO
