-- check that Title is NULL
SELECT * 
FROM	Person.Person
WHERE	BusinessEntityID = 1

-- switch to source to update

-- check that Title is now Mr.
SELECT * 
FROM	Person.Person
WHERE	BusinessEntityID = 1

-- switch to source to reset change

-- check that table now has the new column
SELECT * 
FROM	Person.Person
WHERE	BusinessEntityID = 1

-- switch to source to reset change
