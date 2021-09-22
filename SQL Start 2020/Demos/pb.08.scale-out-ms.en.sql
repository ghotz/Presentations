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
--              The above copyright notice and this permission notice
--              shall be included in all copies or substantial portions
--              of the Software.
--              THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
--              ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
--              LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
--              FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
--              EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
--              FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
--              AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--              OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
--              OTHER DEALINGS IN THE SOFTWARE.
-- Credits:    https://github.com/microsoft/bobsql/blob/master/demos/sqlserver/polybase
------------------------------------------------------------------------

------------------------------------------------------------------------
-- This demo relay on databade Integration created in the previous
-- demo script pb.02.fundamental.en.sql
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Create sample database JustWorldImporters on source SQL Server
-- Create schema using this scripts https://github.com/microsoft/bobsql/blob/master/demos/sqlserver/polybase/sqldatahub/sql2008r2/justwwi_suppliers.sql
------------------------------------------------------------------------
USE Integration;
GO
CREATE SCHEMA Purchasing;
GO
CREATE EXTERNAL TABLE Purchasing.Suppliers
(
	[SupplierID] [int] NOT NULL,
	[SupplierName] [nvarchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[SupplierCategoryID] [int] NOT NULL,
	[PrimaryContactPersonID] [int] NOT NULL,
	[AlternateContactPersonID] [int] NOT NULL,
	[DeliveryMethodID] [int] NULL,
	[DeliveryCityID] [int] NOT NULL,
	[PostalCityID] [int] NOT NULL,
	[SupplierReference] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[BankAccountName] [nvarchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[BankAccountBranch] [nvarchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[BankAccountCode] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[BankAccountNumber] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[BankInternationalCode] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[PaymentDays] [int] NOT NULL,
	[PhoneNumber] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[FaxNumber] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[WebsiteURL] [nvarchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[DeliveryAddressLine1] [nvarchar](60) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[DeliveryAddressLine2] [nvarchar](60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DeliveryPostalCode] [nvarchar](10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[PostalAddressLine1] [nvarchar](60) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[PostalAddressLine2] [nvarchar](60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[PostalPostalCode] [nvarchar](10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[LastEditedBy] [int] NOT NULL
)
 WITH (
 LOCATION='JustWorldImporters.dbo.Suppliers',
 DATA_SOURCE=SQLUX
);
GO

CREATE STATISTICS SupplierNameStatistics
ON	Purchasing.Suppliers ([SupplierName]) WITH FULLSCAN;
GO

------------------------------------------------------------------------
-- Full table scan (1mio rows)
------------------------------------------------------------------------
SELECT * FROM Purchasing.Suppliers;
GO

-- copy, paste, execute in another connection to
-- show temporare tables in tempdb (also in SSMS)
SELECT * FROM tempdb.sys.tables;
GO

------------------------------------------------------------------------
-- Simple query
------------------------------------------------------------------------
SELECT * FROM Purchasing.Suppliers WHERE SupplierName = 'Brooks Brothers';
GO

------------------------------------------------------------------------
-- Join example
------------------------------------------------------------------------
SELECT	s.SupplierName, s.SupplierReference, c.cityname
FROM	Purchasing.Suppliers AS s
JOIN	WideWorldImporters.Purchasing.SupplierCategories as sc
  ON	s.SupplierCategoryID = sc.SupplierCategoryID
 AND	sc.SupplierCategoryName = 'Clothing Supplier'
JOIN	WideWorldImporters.[Application].Cities AS c
  ON	s.DeliveryCityID = c.CityID
GO


SELECT	DR.execution_id, ST.*, DR.*
FROM	sys.dm_exec_distributed_requests AS DR
CROSS
APPLY	sys.dm_exec_sql_text(DR.sql_handle) AS ST
WHERE	ST.[text] LIKE '%Suppliers%'
ORDER BY DR.end_time DESC;
GO

SELECT * FROM sys.dm_exec_distributed_request_steps	WHERE execution_id = 'QID824' ORDER BY step_index;
SELECT * FROM sys.dm_exec_distributed_sql_requests	WHERE execution_id = 'QID824' ORDER BY step_index, compute_node_id, distribution_id;
SELECT * FROM sys.dm_exec_dms_workers				WHERE execution_id = 'QID824' ORDER BY step_index, dms_step_index, compute_node_id, distribution_id;
SELECT * FROM sys.dm_exec_external_work				WHERE execution_id = 'QID824';
GO
