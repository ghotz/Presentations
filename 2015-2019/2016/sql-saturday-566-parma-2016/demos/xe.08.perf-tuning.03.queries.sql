	------------------------------------------------------------------------
--	Script:			xe.08.perf-tuning.03.queries
--	Description:	Workload
--	Author:			Gianluca Hotz (SolidQ)
--	Credits:		Itzik Ben-Gan (SolidQ), Herbert Albert (SolidQ)
--	Copyright:		Attribution-NonCommercial-ShareAlike 3.0
------------------------------------------------------------------------

------------------------------------------------------------------------
--	Basato sul seguente articolo (non più disponibile, chidere a ghotz@ugiss.org):
--	http://www.solidq.com/sqj/Pages/Relational/Tracing-Query-Performance-with-Extended-Events.aspx
--	Lo script per creare il database di test si trova al seguente link
--	http://tsql.solidq.com/SampleDatabases/Performance.txt
------------------------------------------------------------------------
USE Performance;
 
SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderid = 3;
 
SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderid = 5;
 
SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderid = 7;
GO 10
 
SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderdate = '20080212';
 
SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderdate = '20080118';
 
SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderdate = '20080828';
 
SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderdate >= '20080101'
  AND orderdate < '20080201';
 
SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderdate >= '20080401'
  AND orderdate < '20080501';
 
SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderdate >= '20080201'
  AND orderdate < '20090301';
 
SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderdate >= '20080501'
  AND orderdate < '20080601';
GO 3