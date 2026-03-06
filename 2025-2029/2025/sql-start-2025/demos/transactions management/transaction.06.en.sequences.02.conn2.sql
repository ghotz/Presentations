------------------------------------------------------------------------
-- Copyright:   2022 Gianluca Hotz
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
--              
--              The above copyright notice and this permission notice
--              shall be included in all copies or substantial portions
--              of the Software.
--              
--              THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
--              ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
--              LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
--              FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
--              EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
--              FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
--              AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--              OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
--              OTHER DEALINGS IN THE SOFTWARE.
-- Synopsis:    This script is used to demonstrate table sequences
-- 
--              This script will run as connection 2
-- Credits:     
------------------------------------------------------------------------

-- change database context
USE tempdb;
GO

------------------------------------------------------------------------
-- Anti-pattern 1: SELECT/UPDATE in a transaction ("cursor" blocking)
-- (uncomment table hint to force scan)
------------------------------------------------------------------------
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
DECLARE	@SequenceID		int = 4;
DECLARE	@SequenceValue	bigint;
BEGIN TRANSACTION
	SELECT	@SequenceValue = SequenceValue + 1
	FROM	dbo.SequenceTable WITH (INDEX=0)
	WHERE	SequenceID = @SequenceID;

	-- return @id to application and do some work here
	SELECT	@SequenceValue AS SequenceValue;

	UPDATE	dbo.SequenceTable
	SET		SequenceValue = @SequenceValue
	WHERE	SequenceID = @SequenceID;
	
	-- switch to Connection 3 to see blocking

	-- switch to Connection 1 and commit
COMMIT TRANSACTION;
GO

------------------------------------------------------------------------
-- Anti-pattern 2: SELECT/UPDATE in a transaction (duplicates)
------------------------------------------------------------------------
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
DECLARE	@SequenceID		int = 2;
DECLARE	@SequenceValue	bigint;
BEGIN TRANSACTION
	SELECT	@SequenceValue = SequenceValue + 1
	FROM	dbo.SequenceTable
	WHERE	SequenceID = @SequenceID;

	-- return @id to application and do some work here
	SELECT	@SequenceValue AS SequenceValue;
GO
	-- switch to Connection 1

	DECLARE	@SequenceID		int = 2;
	DECLARE	@SequenceValue	bigint = 3;
	UPDATE	dbo.SequenceTable
	SET		SequenceValue = @SequenceValue
	WHERE	SequenceID = @SequenceID;

	-- switch to Connection 3
	
COMMIT TRANSACTION;
GO
--SELECT * FROM dbo.SequenceTable WHERE SequenceID = 2 

------------------------------------------------------------------------
-- Anti-pattern 3: SELECT/UPDATE in a transaction (duplicates and deadlocks)
------------------------------------------------------------------------
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
--SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
DECLARE	@SequenceID		int = 2;
DECLARE	@SequenceValue	bigint;
BEGIN TRANSACTION
	SELECT	@SequenceValue = SequenceValue + 1
	FROM	dbo.SequenceTable
	WHERE	SequenceID = @SequenceID;

	-- return @id to application and do some work here
	SELECT	@SequenceValue AS SequenceValue;
GO
	-- switch to Connection 3 and then 2

	DECLARE	@SequenceID		int = 2;
	DECLARE	@SequenceValue	bigint = 3;
	UPDATE	dbo.SequenceTable
	SET		SequenceValue = @SequenceValue
	WHERE	SequenceID = @SequenceID;
	-- switch to Connection 3 and then 1 to commit

--COMMIT TRANSACTION; -- not needed as this connection is chosen as victim
GO

------------------------------------------------------------------------
-- Pattern 1: SELECT/UPDATE in a transaction no side effects
------------------------------------------------------------------------
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
DECLARE	@SequenceID		int = 2;
DECLARE	@SequenceValue	bigint;
BEGIN TRANSACTION
	SELECT	@SequenceValue = SequenceValue + 1
	FROM	dbo.SequenceTable WITH (UPDLOCK, ROWLOCK)
	WHERE	SequenceID = @SequenceID;

	-- return @id to application and do some work here
	SELECT	@SequenceValue AS SequenceValue;
GO
	-- switch to Connection 3 and then 1

	DECLARE	@SequenceID		int = 2;
	DECLARE	@SequenceValue	bigint = 4;
	UPDATE	dbo.SequenceTable
	SET		SequenceValue = @SequenceValue
	WHERE	SequenceID = @SequenceID;

COMMIT TRANSACTION;
GO

------------------------------------------------------------------------
-- Pattern 2: UPDATE/SELECT in a transaction (deadlocks with diff tx)
------------------------------------------------------------------------
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
DECLARE	@SequenceID		int = 2;
BEGIN TRANSACTION

	UPDATE	dbo.SequenceTable
	SET		SequenceValue = SequenceValue + 1
	WHERE	SequenceID = @SequenceID;
	
	SELECT	SequenceValue
	FROM	dbo.SequenceTable
	WHERE	SequenceID = @SequenceID;

	-- switch to Connection 3

COMMIT TRANSACTION;
GO

------------------------------------------------------------------------
-- Pattern 3: UPDATE/OUTPUT no side effects
------------------------------------------------------------------------
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
DECLARE	@SequenceID		int = 2;
BEGIN TRANSACTION
	UPDATE	dbo.SequenceTable --WITH (ROWLOCK)
	SET		SequenceValue = SequenceValue + 1
	OUTPUT	inserted.SequenceValue AS SequenceValue
	WHERE	SequenceID = @SequenceID;
	
	-- switch to Connection 3 and check locks

COMMIT TRANSACTION;
GO
