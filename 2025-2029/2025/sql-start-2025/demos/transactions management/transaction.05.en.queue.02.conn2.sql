------------------------------------------------------------------------
-- Copyright:   2019 Gianluca Hotz
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
-- Synopsis:    This script is used to demonstrate table queues
-- 
--              This script will run as connection 2
-- Credits:     
------------------------------------------------------------------------

-- change database context
USE tempdb;
GO

------------------------------------------------------------------------
-- Pattern 1: SELECT/UPDATE in a transaction
------------------------------------------------------------------------
DECLARE	@id int;
BEGIN TRANSACTION
	SELECT	TOP(1) @id = Id
	FROM	dbo.QueueTable
	WHERE	IdStatus = 0;

	-- return @id to application and do some work here
	SELECT	@id AS Id;
	
	UPDATE	dbo.QueueTable
	SET		IdStatus = 1
	WHERE	Id = @id;

	-- switch to Connection 3 to see blocking

	-- switch to Connection 1 and commit
COMMIT TRANSACTION;
GO

------------------------------------------------------------------------
-- Pattern 1: SELECT/UPDATE in a transaction parallelized
------------------------------------------------------------------------
DECLARE	@id int;
BEGIN TRANSACTION
	SELECT	TOP(1) @id = Id
	FROM	dbo.QueueTable WITH (READPAST, UPDLOCK, ROWLOCK)
	WHERE	IdStatus = 0;

	-- return @id to application and do some work here
	SELECT	@id AS Id;

	UPDATE	dbo.QueueTable
	SET		IdStatus = 1
	WHERE	Id = @id;

	-- no blocking, switch to Connection 1 and commit

COMMIT TRANSACTION;
GO

------------------------------------------------------------------------
-- Pattern 2: UPDATE/OUTPUT parallelized
------------------------------------------------------------------------
BEGIN TRANSACTION
	UPDATE	TOP(1) dbo.QueueTable WITH (READPAST, ROWLOCK)
	SET		IdStatus = 1
	OUTPUT	inserted.Id AS Id
	WHERE	IdStatus = 0;

	-- switch to Connection 3 anche check locks

COMMIT TRANSACTION;
GO
