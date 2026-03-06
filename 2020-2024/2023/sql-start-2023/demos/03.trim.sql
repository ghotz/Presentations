------------------------------------------------------------------------
-- TRIM
------------------------------------------------------------------------
-- removing specific set of characters in SQL Server 2017+
SELECT '>' + TRIM('.,! ' FROM '!     test    .') + '<' AS Result;

-- this is analogous to using the new BOTH directive in SQL Server 2022+
SELECT '>' + TRIM(BOTH '.,! ' FROM '!     test    .') + '<' AS Result;
GO

-- LEADING extension of TRIM and LTRIM in SQL Server 2022+
SELECT '>' + TRIM(LEADING '.,! ' FROM '!     test    .') + '<' AS Result;
SELECT '>' + LTRIM('!     test    .', '.,! ') + '<' AS Result;
GO

-- TRAILING extension of TRIM and RTRIM in SQL Server 2022+
SELECT '>' + TRIM(TRAILING '.,! ' FROM '!     test    .') + '<' AS Result;
SELECT '>' + RTRIM('!     test    .', '.,! ') + '<' AS Result;
GO
