USE WideWorldImporters;
GO
SELECT
		DATE_BUCKET(week, 1, InvoiceDate) as InvoiceWeek
	,	COUNT(CustomerId) as CustomerCount
FROM	Sales.Invoices
GROUP BY
	DATE_BUCKET(week, 1, InvoiceDate)
  ORDER BY InvoiceWeek
GO
SELECT
		DATE_BUCKET(week, 2, InvoiceDate) as InvoiceWeek
	,	COUNT(CustomerId) as CustomerCount
FROM	Sales.Invoices
GROUP BY
	DATE_BUCKET(week, 2, InvoiceDate)
  ORDER BY InvoiceWeek
GO

SELECT
		DATE_BUCKET(month, 1, InvoiceDate) as InvoiceWeek
	,	COUNT(CustomerId) as CustomerCount
FROM	Sales.Invoices
GROUP BY
	DATE_BUCKET(month, 1, InvoiceDate)
  ORDER BY InvoiceWeek
GO
SELECT
		DATE_BUCKET(month, 6, InvoiceDate) as InvoiceWeek
	,	COUNT(CustomerId) as CustomerCount
FROM	Sales.Invoices
GROUP BY
	DATE_BUCKET(month, 6, InvoiceDate)
  ORDER BY InvoiceWeek
GO
