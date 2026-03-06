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
--              This script will run as connection 1
-- Credits:     
------------------------------------------------------------------------

-- change database context
USE tempdb;
GO
------------------------------------------------------------------------
-- Just create a simple ssequence table and insert some data
------------------------------------------------------------------------
DROP TABLE IF EXISTS dbo.SequenceTable;
CREATE TABLE dbo.SequenceTable(
	SequenceID		int		NOT NULL PRIMARY KEY
,	SequenceValue	bigint	NOT NULL DEFAULT (0)
)
GO

INSERT	dbo.SequenceTable
VALUES	(1, 0), (2, 0), (3, 0),	(4, 0), (5, 0);
GO

------------------------------------------------------------------------
-- Anti-pattern 1: SELECT/UPDATE in a transaction ("cursor" blocking)
-- (uncomment table hint to force scan)
------------------------------------------------------------------------
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
DECLARE	@SequenceID		int = 2;
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

	-- switch to Connection 2
	
COMMIT TRANSACTION;
-- switch to Connection 2 and commit
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
	-- switch to Connection 2

	DECLARE	@SequenceID		int = 2;
	DECLARE	@SequenceValue	bigint = 3;
	UPDATE	dbo.SequenceTable
	SET		SequenceValue = @SequenceValue
	WHERE	SequenceID = @SequenceID;
	-- switch to Connection 2
	
COMMIT TRANSACTION;
-- switch to Connection 2 and commit
GO
-- switch to Connection 2 and complete transaction

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
	-- switch to Connection 2

	DECLARE	@SequenceID		int = 2;
	DECLARE	@SequenceValue	bigint = 4;
	UPDATE	dbo.SequenceTable
	SET		SequenceValue = @SequenceValue
	WHERE	SequenceID = @SequenceID;
	-- switch to Connection 3 and then 2
	
COMMIT TRANSACTION;
GO

------------------------------------------------------------------------
-- Pattern 1: SELECT/UPDATE in a transaction (deadlocks with diff tx)
--
-- Note: for XLOCK there's an optimization that allows reading under
-- read committed (non snapshot) if data is not changed, so in practice
-- it behaves as an UPLOCK but at least with latter, side effects are
-- more clear
-- https://web.archive.org/web/20170602185207/http://sqlblog.com/blogs/paul_white/archive/2010/11/01/read-committed-shared-locks-and-rollbacks.aspx
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
	-- switch to Connection 2

	DECLARE	@SequenceID		int = 2;
	DECLARE	@SequenceValue	bigint = 4;
	UPDATE	dbo.SequenceTable
	SET		SequenceValue = @SequenceValue
	WHERE	SequenceID = @SequenceID;

	-- switch to Connection 3 and then 1 to commit

COMMIT TRANSACTION;
GO
-- switch to Connection 2 to complete transaction

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

	-- switch to Connection 2

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
	
	-- switch to Connection 2

COMMIT TRANSACTION;
GO

------------------------------------------------------------------------
-- Pattern 4: UPDATE/OUTPUT with variable no side effects
------------------------------------------------------------------------
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
DECLARE	@SequenceID		int = 2;
DECLARE	@SequenceValueT	TABLE (SequenceValue bigint NOT NULL PRIMARY KEY);
DECLARE	@SequenceValue	bigint;

BEGIN TRANSACTION
	UPDATE	dbo.SequenceTable --WITH (ROWLOCK)
	SET		SequenceValue = SequenceValue + 1
	OUTPUT	inserted.SequenceValue AS SequenceValue
	INTO	@SequenceValueT
	WHERE	SequenceID = @SequenceID;
	
	SELECT	@SequenceValue = SequenceValue FROM @SequenceValueT;
	SELECT	@SequenceValue AS SequenceValue;

COMMIT TRANSACTION;
GO
