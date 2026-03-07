------------------------------------------------------------------------
-- Script:			02.spatial-xmas.sql
-- Last update:		2012-01-20
-- Author:			Gianluca Hotz  (SolidQ)
-- Credits:			http://social.msdn.microsoft.com/Forums/en/sqlspatial/thread/d52c686e-30cc-4ae0-bdc7-ae4a2536cd64
-- Copyright:		Attribution-NonCommercial-ShareAlike 3.0
-- Versions:		SQL2008R2
--
-- Description:		Demonstrate Spatial Data
-------------------------------------------------------------------------

-- Christmas spatial
-- Credits: http://social.msdn.microsoft.com/Forums/en/sqlspatial/thread/d52c686e-30cc-4ae0-bdc7-ae4a2536cd64
--
USE tempdb;
GO

-- Prepare the scene
CREATE TABLE #ChristmasScene (
  item varchar(32),
  shape geometry);

-- Put up the tree and star
INSERT INTO #ChristmasScene VALUES
('Tree', 'POLYGON((4 0, 0 0, 3 2, 1 2, 3 4, 1 4, 3 6, 2 6, 4 8, 6 6, 5 6, 7 4, 5 4, 7 2, 5 2, 8 0, 4 0))'),
('Base', 'POLYGON((2.5 0, 3 -1, 5 -1, 5.5 0, 2.5 0))'),
('Star', 'POLYGON((4 7.5, 3.5 7.25, 3.6 7.9, 3.1 8.2, 3.8 8.2, 4 8.9, 4.2 8.2, 4.9 8.2, 4.4 7.9, 4.5 7.25, 4 7.5))')

-- Decorate the tree
DECLARE @i int = 0, @x int, @y int;
WHILE (@i < 20)
BEGIN
  INSERT INTO #ChristmasScene VALUES 
    ('Bubble' + CAST(@i AS varchar(8)), geometry::Point(RAND() * 5 +1.5, RAND() * 6, 0).STBuffer(0.3))
  SET @i = @i + 1;
END

-- Christmas Greeting
INSERT INTO #ChristmasScene VALUES
('M', 'POLYGON((0 10, 0 11, 0.25 11, 0.5 10.5, 0.75 11, 1 11, 1 10, 0.75 10, 0.75 10.7, 0.5 10.2, 0.25 10.7, 0.25 10, 0 10))'),
('E', 'POLYGON((1 10, 1 11, 2 11, 2 10.8, 1.25 10.8, 1.25 10.6, 1.75 10.6, 1.75 10.4, 1.25 10.4, 1.25 10.2, 2 10.2, 2 10, 1 10))'),
('R', 'POLYGON((2 10, 2 11, 3 11, 3 10.5, 2.4 10.5, 3 10, 2.7 10, 2.2 10.4, 2.2 10, 2 10),(2.2 10.8, 2.8 10.8, 2.8 10.7, 2.2 10.7, 2.2 10.8))'),
('R', 'POLYGON((3 10, 3 11, 4 11, 4 10.5, 3.4 10.5, 4 10, 3.7 10, 3.2 10.4, 3.2 10, 3 10),(3.2 10.8, 3.8 10.8, 3.8 10.7, 3.2 10.7, 3.2 10.8))'),
('Y', 'POLYGON((4 11, 4.2 11, 4.5 10.6, 4.8 11, 5 11, 4.6 10.5, 4.6 10, 4.4 10, 4.4 10.5, 4 11))'),
('C', 'POLYGON((0 9, 0 10, 1 10, 1 9.8, 0.2 9.8, 0.2 9.2, 1 9.2, 1 9, 0 9))'),
('H', 'POLYGON((1 9, 1 10, 1.2 10, 1.2 9.6, 1.8 9.6, 1.8 10, 2 10, 2 9, 1.8 9, 1.8 9.4, 1.2 9.4, 1.2 9, 1 9))'),
('R', 'POLYGON((2 9, 2 10, 3 10, 3 9.5, 2.4 9.5, 3 9, 2.7 9, 2.2 9.4, 2.2 9, 2 9),(2.2 9.8, 2.8 9.8, 2.8 9.7, 2.2 9.7, 2.2 9.8))'),
('I', 'POLYGON((3.2 9, 3.2 9.2, 3.4 9.2, 3.4 9.8, 3.2 9.8, 3.2 10, 3.8 10, 3.8 9.8, 3.6 9.8, 3.6 9.2, 3.8 9.2, 3.8 9, 3.2 9))'),
('S', 'POLYGON((4 9, 4 9.2, 4.8 9.2, 4.8 9.4, 4 9.4, 4 10, 5 10, 5 9.8, 4.2 9.8, 4.2 9.6, 5 9.6, 5 9, 4 9))'),
('T', 'POLYGON((5 9.8, 5 10, 6 10, 6 9.8, 5.6 9.8, 5.6 9, 5.4 9, 5.4 9.8, 5 9.8))'),
('M', 'POLYGON((6 9, 6 10, 6.25 10, 6.5 9.5, 6.75 10, 7 10, 7 9, 6.75 9, 6.75 9.7, 6.5 9.2, 6.25 9.7, 6.25 9, 6 9))'),
('A', 'POLYGON((7 9, 7 10, 8 10, 8 9, 7.75 9, 7.75 9.3, 7.25 9.3, 7.25 9, 7 9),(7.25 9.5, 7.25 9.8, 7.75 9.8, 7.75 9.5, 7.25 9.5))'),
('S', 'POLYGON((8 9, 8 9.2, 8.8 9.2, 8.8 9.4, 8 9.4, 8 10, 9 10, 9 9.8, 8.2 9.8, 8.2 9.6, 9 9.6, 9 9, 8 9))');

-- Admire the scene
SELECT * FROM #ChristmasScene

-- Tidy up the pine needles and put away the decorations
DROP TABLE #ChristmasScene
