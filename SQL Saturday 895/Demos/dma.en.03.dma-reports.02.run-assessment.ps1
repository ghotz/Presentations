#
# Consolidate assessment report
# Note: install everything as described in https://docs.microsoft.com/en-us/sql/dma/dma-consolidatereports
# Errors logged in C:\Users\gianl\AppData\Local\DataMigrationAssistant
#


# run assessment against all configure instances
dmaDataCollector `
    -getServerListFrom SqlServer `
    -serverName localhost `
    -databaseName EstateInventory `
    -AssessmentName "Demo Assessment" `
    -TargetPlatform AzureSqlDatabase `
    -OutputLocation C:\temp\dma\consolidated\ `
    -AuthenticationMethod WindowsAuth

# import data into database
dmaProcessor `
    -processTo SQLServer `
    -serverName localhost `
    -CreateDMAReporting 1 `
    -CreateDataWarehouse 1 `
    -databaseName DMAReporting `
    -warehouseName DMAWarehouse `
    -jsonDirectory C:\temp\dma\consolidated\


Invoke-Sqlcmd -ServerInstance localhost -InputFile "C:\Users\gianl\OneDrive\Documents\Presentations\Topics\Demos\migrations\LoadWarehouse.sql"
