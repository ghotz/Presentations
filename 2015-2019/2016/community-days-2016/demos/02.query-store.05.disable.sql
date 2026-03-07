------------------------------------------------------------------------
--	Description:	Query store demo disable
------------------------------------------------------------------------
USE master;
GO

ALTER DATABASE [QueryStore] SET QUERY_STORE CLEAR;
GO
ALTER DATABASE [QueryStore] SET QUERY_STORE = OFF;
GO


