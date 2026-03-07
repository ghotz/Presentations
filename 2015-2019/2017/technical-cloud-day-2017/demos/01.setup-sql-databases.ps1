# https://docs.microsoft.com/en-us/azure/sql-database/sql-database-get-started-powershell

#$VerbosePreference = "continue";


# Connect to MSDN Subscription (Get-AzureRmSubscription to get list)
# Add-AzureRmAccount -SubscriptionName "MSDN SolidQ IT Data Management General Purpose";
# Add-AzureRmAccount -SubscriptionName "MVP Windows Azure MSDN";

#
# Get or create resource group
#
$resourceGroupName = "AzureDBDemoResources";
$resourceGroupLocation = "West Europe";

$myResourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ea SilentlyContinue;

if(!$myResourceGroup)
{
   Write-Verbose "Creating resource group: $resourceGroupName";
   $myResourceGroup = New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation;
}
else
{
   Write-Verbose "Resource group $resourceGroupName already exists";
}

#
# Get or create logical SQL Server
#
$serverName = "azuredbdemo";
$serverVersion = "12.0";
$serverLocation = $resourceGroupLocation;
$serverResourceGroupName = $resourceGroupName;

$serverAdmin = "ghotz";
$serverAdminPassword = "Tusa.1971";

$securePassword = ConvertTo-SecureString -String $serverAdminPassword -AsPlainText -Force;
$serverCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $serverAdmin, $securePassword;

$myServer = Get-AzureRmSqlServer -ServerName $serverName -ResourceGroupName $serverResourceGroupName -ea SilentlyContinue;
if(!$myServer)
{
   Write-Verbose "Creating SQL server: $serverName";
   $myServer = New-AzureRmSqlServer -ResourceGroupName $serverResourceGroupName -ServerName $serverName -Location $serverLocation -ServerVersion $serverVersion -SqlAdministratorCredentials $serverCreds;
}
else
{
   Write-Verbose "SQL server $serverName already exists";
}

#
# Get or create Firewall rules
#

# Allow Azure services
$myFirewallRule = Get-AzureRmSqlServerFirewallRule -FirewallRuleName "AllowAllAzureIPs" -ServerName $serverName -ResourceGroupName $serverResourceGroupName -ea SilentlyContinue;

if(!$myFirewallRule)
{
    Write-Verbose "Creating server firewall to allow all Azure IP addresses";
    New-AzureRmSqlServerFirewallRule -ResourceGroupName $serverResourceGroupName -ServerName $serverName -AllowAllAzureIPs;
}
else
{
   Write-Verbose "Server firewall rule to allow all Azure IP addresses already exists";
}


# allow a specific IP address range
$serverFirewallRuleName = "Home Alphasys";
$serverFirewallStartIp = "88.149.182.18";
$serverFirewallEndIp = "88.149.182.18";

$myFirewallRule = Get-AzureRmSqlServerFirewallRule -FirewallRuleName $serverFirewallRuleName -ServerName $serverName -ResourceGroupName $serverResourceGroupName -ea SilentlyContinue;

if(!$myFirewallRule)
{
   Write-Verbose "Creating server firewall rule: $serverFirewallRuleName";
   $myFirewallRule = New-AzureRmSqlServerFirewallRule -ResourceGroupName $serverResourceGroupName -ServerName $serverName -FirewallRuleName $serverFirewallRuleName -StartIpAddress $serverFirewallStartIp -EndIpAddress $serverFirewallEndIp;
}
else
{
   Write-Verbose "Server firewall rule $serverFirewallRuleName already exists";
}

# Allow all IP addresses
$serverFirewallRuleName = "All Addresses";
$serverFirewallStartIp = "0.0.0.0";
$serverFirewallEndIp = "255.255.255.255";

$myFirewallRule = Get-AzureRmSqlServerFirewallRule -FirewallRuleName $serverFirewallRuleName -ServerName $serverName -ResourceGroupName $serverResourceGroupName -ea SilentlyContinue;

if(!$myFirewallRule)
{
   Write-Verbose "Creating server firewall rule: $serverFirewallRuleName";
   $myFirewallRule = New-AzureRmSqlServerFirewallRule -ResourceGroupName $serverResourceGroupName -ServerName $serverName -FirewallRuleName $serverFirewallRuleName -StartIpAddress $serverFirewallStartIp -EndIpAddress $serverFirewallEndIp;
}
else
{
   Write-Verbose "Server firewall rule $serverFirewallRuleName already exists";
}

#Remove-AzureRmSqlServerFirewallRule -ResourceGroupName $serverResourceGroupName -ServerName $serverName -FirewallRuleName "All Addresses"

#
# Get or create storage account for database bacpacs
#
$storageAccountName = "azuredbdemoblobs";
$storageAccountResourceGroupName = $resourceGroupName;
$storageAccountLocation = $resourceGroupLocation;
$storageAccountSKUName = "Standard_GRS";
$storageAccountKind = "BlobStorage";
$storageAccountAccessTier = "Hot";

$myStorageAccount = Get-AzureRmStorageAccount -Name $storageAccountName -ResourceGroupName $storageAccountResourceGroupName -ea SilentlyContinue;

if(!$myStorageAccount)
{
   Write-Verbose "Creating storage account: $storageAccountName";
   $myStorageAccount = New-AzureRmStorageAccount -ResourceGroupName $storageAccountResourceGroupName -Name $storageAccountName -Location $storageAccountLocation -SkuName $storageAccountSKUName -Kind $storageAccountKind -AccessTier $storageAccountAccessTier;
}
else
{
   Write-Verbose "Storage account $storageAccountName already exists";
}

#
# Get or create blob container
# 
# Note: *AzureRm* cmdlets are missing for some items
# 
# $StorageContext = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey (Get-AzureRmStorageAccountKey -ResourceGroupName $storageAccountResourceGroupName -Name $storageAccountName)[0].Value;
# Remove-AzureStorageContainer -Name $StorageContainerName -Context $myStorageAccount.Context;
#
$StorageContainerName = "bacpacs";

$myStorageContainer = Get-AzureStorageContainer -name $StorageContainerName -Context $myStorageAccount.Context -ea SilentlyContinue;

if(!$myStorageContainer)
{
   Write-Verbose "Creating storage container: $StorageContainerName";
   $myStorageContainer = New-AzureStorageContainer -Name $StorageContainerName -Context $myStorageAccount.Context;
}
else
{
   Write-Verbose "Storage container $StorageContainerName already exists";
}

#
# Upload demo database bacpac
#
$UploadFile = @{
    Context = $myStorageAccount.Context;
    Container = $StorageContainerName;
    File = "C:\temp\AdventureWorks2012.bacpac";
    }
Set-AzureStorageBlobContent @UploadFile;

#
# Create AdventureWorks2012 demo database by restoring bacpac
#
# Note: we are starting with Standard/S1 to import fast then we are going back to Basic/Basic
#
#$resourceGroupName = "{resource-group-name}"
#$serverName = "{server-name}"

$databaseName = "AzureDemoDB01"
$databaseEdition = "Standard"
$databaseServiceLevel = "S1"

$storageKeyType = "StorageAccessKey"
$storageUri = "https://azuredbdemoblobs.blob.core.windows.net/bacpacs/AdventureWorks2012.bacpac"; # URL of bacpac file you uploaded to your storage account
$storageKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $storageAccountResourceGroupName -Name $storageAccountName)[0].Value; # key1 in the Access keys setting of your storage account

$importRequest = New-AzureRmSqlDatabaseImport -ResourceGroupName $resourceGroupName -ServerName $serverName -DatabaseName $databaseName -StorageKeytype $storageKeyType -StorageKey $storageKey -StorageUri $storageUri -AdministratorLogin $serverAdmin -AdministratorLoginPassword $securePassword -Edition $databaseEdition -ServiceObjectiveName $databaseServiceLevel -DatabaseMaxSizeBytes 5000000;

Do {
     $importStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
     Write-Verbose ("Importing database..." + $importStatus.StatusMessage)
     Start-Sleep -Seconds 15
     $importStatus.Status
   }
   until ($importStatus.Status -eq "Succeeded")
$importStatus

# change back to a cheaper tier
$NewEdition = "Basic";
$NewPricingTier = "Basic";
Set-AzureRmSqlDatabase -DatabaseName $DatabaseName -ServerName $ServerName -ResourceGroupName $ResourceGroupName -Edition $NewEdition -RequestedServiceObjectiveName $NewPricingTier;

#
# Activate Query Store
#
Invoke-SqlCmd -ServerInstance "$ServerName.database.windows.net" -Database $DatabaseName -Query "ALTER DATABASE [AzureDemoDB01] SET QUERY_STORE = ON" -Username $serverAdmin -Password $serverAdminPassword

#
# Create other demo empty databases
#
#New-AzureRmSqlDatabase -DatabaseName "AzureDemoDB01"  -Edition "Basic" -RequestedServiceObjectiveName "Basic" -ServerName $serverName -ResourceGroupName $resourceGroupName;
#New-AzureRmSqlDatabase -DatabaseName "AzureDemoDB02"  -Edition "Basic" -RequestedServiceObjectiveName "Basic" -ServerName $serverName -ResourceGroupName $resourceGroupName;
#New-AzureRmSqlDatabase -DatabaseName "AzureDemoDB03"  -Edition "Basic" -RequestedServiceObjectiveName "Basic" -ServerName $serverName -ResourceGroupName $resourceGroupName;

#
# ... or copy first database as additional databases (monitor with SELECT * FROM sys.dm_database_copies in master)
#
New-AzureRmSqlDatabaseCopy -ServerName $ServerName -ResourceGroupName $ResourceGroupName -DatabaseName "AzureDemoDB01" -CopyDatabaseName "AzureDemoDB02"
New-AzureRmSqlDatabaseCopy -ServerName $ServerName -ResourceGroupName $ResourceGroupName -DatabaseName "AzureDemoDB01" -CopyDatabaseName "AzureDemoDB03"
New-AzureRmSqlDatabaseCopy -ServerName $ServerName -ResourceGroupName $ResourceGroupName -DatabaseName "AzureDemoDB01" -CopyDatabaseName "AzureDemoDB04"

#
# Enable all database advisors for the logical SQL server
#
Get-AzureRmSqlServerAdvisor -ServerName $ServerName -ResourceGroupName $ResourceGroupName | ? { $_.AutoExecuteStatus -ne "Enabled" } | Set-AzureRmSqlServerAdvisorAutoExecuteStatus -AutoExecuteStatus Enabled

#
# Get or create storage account for auditing
#
$storageAccountName = "azuredbdemoaudit";
$storageAccountResourceGroupName = $resourceGroupName;
$storageAccountLocation = $resourceGroupLocation;
$storageAccountSKUName = "Standard_GRS";
$storageAccountKind = "Storage";
#$storageAccountAccessTier = "Hot";

$myStorageAccount = Get-AzureRmStorageAccount -Name $storageAccountName -ResourceGroupName $storageAccountResourceGroupName -ea SilentlyContinue;

if(!$myStorageAccount)
{
   Write-Verbose "Creating storage account: $storageAccountName";
   $myStorageAccount = New-AzureRmStorageAccount -ResourceGroupName $storageAccountResourceGroupName -Name $storageAccountName -Location $storageAccountLocation -SkuName $storageAccountSKUName -Kind $storageAccountKind; # -AccessTier $storageAccountAccessTier;
}
else
{
   Write-Verbose "Storage account $storageAccountName already exists";
}

#
# Enable Auditing (couldn't make it work with Blob storage...)
#
Set-AzureRmSqlServerAuditingPolicy -ServerName $ServerName -ResourceGroupName $ResourceGroupName -StorageAccountName $storageAccountName -StorageKeyType Primary -RetentionInDays 7 -TableIdentifier "AzureDBDemo";


#
# Enable Threat Detection
#
Set-AzureRmSqlServerThreatDetectionPolicy -ServerName $ServerName -ResourceGroupName $ResourceGroupName -EmailAdmins $true -StorageAccountName $storageAccountName -RetentionInDays 7 -NotificationRecipientsEmails "gianluca_hotz@hotmail.com";


#
# Elastic Pools
#

# Create new elastic pool
New-AzureRmSqlElasticPool -ServerName $ServerName -ResourceGroupName $ResourceGroupName -ElasticPoolName "AzureDBDemoPool" -Edition "Standard" -Dtu 50 -DatabaseDtuMin 10 -DatabaseDtuMax 50;

# Move databases to pool
Set-AzureRmSqlDatabase -ServerName $ServerName -ResourceGroupName $ResourceGroupName -DatabaseName "AzureDemoDB01" -ElasticPoolName "AzureDBDemoPool"
Set-AzureRmSqlDatabase -ServerName $ServerName -ResourceGroupName $ResourceGroupName -DatabaseName "AzureDemoDB02" -ElasticPoolName "AzureDBDemoPool"
Set-AzureRmSqlDatabase -ServerName $ServerName -ResourceGroupName $ResourceGroupName -DatabaseName "AzureDemoDB03" -ElasticPoolName "AzureDBDemoPool"
#Set-AzureRmSqlDatabase -ServerName $ServerName -ResourceGroupName $ResourceGroupName -DatabaseName "AzureDemoDB04" -ElasticPoolName "AzureDBDemoPool"

#Get-AzureRmSqlDatabaseActivity -ServerName "azuredbdemo" -ResourceGroupName "AzureDBDemoResources" -ElasticPoolName "AzureDBDemoPool" -DatabaseName "AzureDemoDB01" 
# See also https://gist.github.com/billgib/d80c7687b17355d3c2ec8042323819ae for moving all databases of a logical SQL server to a pool

#
# Random Queries
#
$Queries = Get-Content -Delimiter "--" -Path "C:\Users\Gianluca\OneDrive\Documents\Presentations\UGISS\20170201 Technical Cloud Day 2017\Demos\advqueries.sql"
$Iterations = 100;

$connectionString = "Server=tcp:" + "azuredbdemo" + ".database.windows.net" + ",1433;Initial Catalog=" + "AzureDemoDB01" + ";Persist Security Info=False;User ID=ghotz;Password=Passw0rd!" + ";MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString
$connection.Open()

while($Iterations-- -gt 0) 
{ 
    try
    {
        $Query = Get-Random -InputObject $Queries;
        $command = New-Object System.Data.SQLClient.SQLCommand($Query, $connection);
        $command.ExecuteNonQuery() | Out-Null;
        $Command.Dispose();
        Start-Sleep -Milliseconds 500;
    }
    catch
    {
        Write-Output "Error while executing query";
        $connection.Close();
        $connection.Open();
    }
}
$connection.Close()
