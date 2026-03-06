USE tempdb;
-- Sample schema:
DROP TABLE IF EXISTS Accounts;
CREATE TABLE Accounts (
	AccountNumber varchar(10) NOT NULL PRIMARY KEY,
	Phone1 varchar(20) NULL,
	Phone2 varchar(20) NULL,
	Phone3 varchar(20) NULL
);
INSERT INTO Accounts (AccountNumber, Phone1, Phone2, Phone3)
VALUES('AW29825', '(123)456-7890', '(123)567-8901', NULL),
	('AW73565', '(234)0987-654', NULL, NULL);
DROP TABLE IF EXISTS Orders;
CREATE TABLE Orders (
	OrderNumber varchar(10) NOT NULL PRIMARY KEY,
	OrderTime datetime2 NOT NULL,
	AccountNumber varchar(10) NOT NULL,
	Price decimal(10, 2) NOT NULL,
	Quantity int NOT NULL
);

-- Input JSON document example:
DECLARE @json nvarchar(1000) = N'
[
    {
        "OrderNumber": "S043659",
        "Date":"2022-05-24T08:01:00",
        "AccountNumber":"AW29825",
        "Price":59.99,
        "Quantity":1
    },
    {
        "OrderNumber": "S043661",
        "Date":"2022-05-20T12:20:00",
        "AccountNumber":"AW73565",
        "Price":24.99,
        "Quantity":3
    }
]';
-- Test for valid JSON array and a specific SQL/JSON path:
SELECT ISJSON(@json, ARRAY) AS IsValidJSONArray, JSON_PATH_EXISTS(@json, '$[0].OrderNumber') AS OrderNumberExists;

-- Transform JSON string into relational data using OPENJSON operator:
INSERT INTO Orders (OrderNumber, OrderTime, AccountNumber, Price, Quantity)
  SELECT T.OrderNumber, T.OrderTime, T.AccountNumber, T.Price, T.Quantity
  FROM OPENJSON(@json)
		WITH(
			OrderNumber varchar(10) '$.OrderNumber',
			OrderTime datetime2 '$.Date',
			AccountNumber varchar(10) '$.AccountNumber',
			Price decimal(10, 2) '$.Price',
			Quantity int '$.Quantity'
			) AS T;

SELECT * FROM Orders;

-- Transform relational data into a JSON string using JSON_OBJECT function:
SELECT o.OrderNumber, JSON_OBJECT('Date':o.OrderTime, 'AccountNumber':o.AccountNumber, 'Price':o.Price, 'Quantity':o.Quantity) AS OrderDetails
  FROM Orders AS o;

-- Transform relational data into a JSON string:
-- Approach using the new JSON_OBJECT & JSON_ARRAY functions:
SELECT o.OrderNumber,
		JSON_OBJECT('Date':o.OrderTime, 'Price':o.Price, 'Quantity':o.Quantity, 
			'AccountDetails':JSON_OBJECT('AccountNumber':o.AccountNumber, 'PhoneNumbers':JSON_ARRAY(a.Phone1, a.Phone2, a.Phone3))) AS OrderDetails
  FROM Orders AS o
  JOIN Accounts AS a
    ON a.AccountNumber = o.AccountNumber;

-- One approach with the existing FOR JSON operator:
SELECT o.OrderNumber,
	(SELECT o.OrderTime as Date, o.Price, o.Quantity,
		(SELECT a.AccountNumber, JSON_QUERY(CONCAT('[',
			CONCAT_WS(',', QUOTENAME(a.Phone1, '"'),			
				QUOTENAME(a.Phone2, '"'),
				QUOTENAME(a.Phone3, '"')), ']')) AS PhoneNumbers
		    FOR JSON PATH) AS AccountDetails
	    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS OrderDetails
  FROM Orders AS o
  JOIN Accounts AS a
    ON a.AccountNumber = o.AccountNumber;