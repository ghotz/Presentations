RESTORE FILELISTONLY FROM DISK = 'F:\Backups\SQL Server\AdventureWorks2022.bak'
GO
RESTORE DATABASE AdventureWorks FROM DISK = 'F:\Backups\SQL Server\AdventureWorks2022.bak'
WITH MOVE 'AdventureWorks2022' TO 'E:\SQLServer\MSSQL17.SQL2025\MSSQL\DATA\AdventureWorks.mdf',
MOVE 'AdventureWorks2022_Log' TO 'E:\SQLServer\MSSQL17.SQL2025\MSSQL\DATA\AdventureWorks_log.ldf'
GO