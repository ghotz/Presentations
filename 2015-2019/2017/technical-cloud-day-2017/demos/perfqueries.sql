SELECT D1.attr1 AS x, D2.attr1 AS y, D3.attr1 AS z,
COUNT(*) AS cnt, SUM(F.measure1) AS total
FROM dbo.Fact AS F
INNER JOIN dbo.Dim1 AS D1
ON F.key1 = D1.key1
INNER JOIN dbo.Dim2 AS D2
ON F.key2 = D2.key2
INNER JOIN dbo.Dim3 AS D3
ON F.key3 = D3.key3
WHERE D1.attr1 <= 10
AND D2.attr1 <= 15
AND D3.attr1 <= 10
GROUP BY D1.attr1, D2.attr1, D3.attr1;
--
SELECT shipperid
FROM dbo.Shippers AS S
WHERE (SELECT MAX(orderdate)
FROM dbo.Orders AS O
WHERE O.shipperid = S.shipperid) < '20160101';
--
SELECT shipperid
FROM dbo.Shippers AS S
WHERE (SELECT TOP (1) orderdate
FROM dbo.Orders AS O
WHERE O.shipperid = S.shipperid
ORDER BY orderdate DESC) < '20160101';
--
SELECT shipperid
FROM dbo.Shippers AS S
WHERE NOT EXISTS
(SELECT * FROM dbo.Orders AS O
WHERE O.shipperid = S.shipperid
AND O.orderdate >= '20160101')
AND EXISTS
(SELECT * FROM dbo.Orders AS O
WHERE O.shipperid = S.shipperid);
--
