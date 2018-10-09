------------------------------------------------------------------------
-- Script:		sp_whoisactive-02-queries.sql
-- Copyright:	2018 Gianluca Hotz
-- License:		MIT License
-- Credits:
------------------------------------------------------------------------

------------------------------------------------------------------------
-- First Workload (Case 1-3)
------------------------------------------------------------------------
USE [AdventureWorksDW2017];
GO

DROP TABLE IF EXISTS tempdb.dbo.tmp;
DBCC DROPCLEANBUFFERS;
SELECT DimCustomer.CustomerKey ,
       DimCustomer.GeographyKey ,
       DimGeography.GeographyKey AS Expr1 ,
       DimGeography.StateProvinceCode ,
       DimReseller.ResellerKey ,
       DimReseller.ResellerAlternateKey ,
       DimReseller.Phone
INTO	tempdb.dbo.tmp
FROM   DimGeography
       INNER JOIN DimReseller ON DimGeography.GeographyKey = DimReseller.GeographyKey
       INNER JOIN DimCustomer ON DimGeography.GeographyKey = DimCustomer.GeographyKey
       CROSS JOIN DimCurrency;
GO 1000

------------------------------------------------------------------------
-- Second Workload (Case 4-8)
------------------------------------------------------------------------
-- Create a graph demo database
USE master;
GO
IF EXISTS (SELECT * FROM sys.databases WHERE [name] = 'TestDB') DROP DATABASE TestDB;
GO
CREATE DATABASE TestDB;
GO

DROP TABLE IF EXISTS TestDB.dbo.tmp;
CREATE TABLE TestDB.dbo.tmp (Field1	int NOT NULL PRIMARY KEY);
INSERT TestDB.dbo.tmp VALUES (1),(2),(3);
GO

BEGIN TRANSACTION;
	UPDATE TestDB.dbo.tmp SET Field1 = 4 WHERE Field1 = 2;
	-- Switch to a new connection and run
	-- SELECT * FROM TestDB.dbo.tmp
GO

ROLLBACK TRANSACTION;
GO


