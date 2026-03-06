USE AdventureWorks2022;
GO
DROP TABLE IF EXISTS Production.IllustrationComp;
SELECT * INTO Production.IllustrationComp FROM Production.Illustration;
GO

EXEC sp_spaceused 'Production.IllustrationComp';
GO
-- SQL Server 2022 add estimate for XML compression
EXEC sp_estimate_data_compression_savings
		@schema_name = 'Production'
	,	@object_name = 'IllustrationComp'
	,	@index_id = NULL
	,	@partition_number = NULL
	,	@data_compression = 'PAGE'
	,	@xml_compression = 0;
GO
EXEC sp_estimate_data_compression_savings
		@schema_name = 'Production'
	,	@object_name = 'IllustrationComp'
	,	@index_id = NULL
	,	@partition_number = NULL
	,	@data_compression = NULL
	,	@xml_compression = 1;
GO
ALTER TABLE [Production].[IllustrationComp]
REBUILD WITH (XML_COMPRESSION = ON);
GO
EXEC sp_spaceused 'Production.Illustration';
EXEC sp_spaceused 'Production.IllustrationComp';
GO
--ALTER TABLE [Production].[IllustrationComp]
--REBUILD WITH (XML_COMPRESSION = OFF);
--GO
--EXEC sp_spaceused 'Production.Illustration';
--EXEC sp_spaceused 'Production.IllustrationComp';
--GO
