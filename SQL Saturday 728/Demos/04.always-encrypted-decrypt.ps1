# Generated by SQL Server Management Studio at 14:36 on 24/02/2017

# You may need to run Install-Module SqlServer -AllowCLobber (with admin privileges)
Import-Module SqlServer;

# Set up connection and database SMO objects

$sqlConnectionString = "Data Source=localhost;Initial Catalog=Clinic;Integrated Security=True;MultipleActiveResultSets=False;Connect Timeout=30;Encrypt=False;TrustServerCertificate=False;Packet Size=4096;Application Name=`"Microsoft SQL Server Management Studio`";Column Encryption Setting=Enabled"
$smoDatabase = Get-SqlDatabase -ConnectionString $sqlConnectionString

# If your encryption changes involve keys in Azure Key Vault, uncomment one of the lines below in order to authenticate:
#   * Prompt for a username and password:
#Add-SqlAzureAuthenticationContext -Interactive

#   * Enter a Client ID, Secret, and Tenant ID:
#Add-SqlAzureAuthenticationContext -ClientID '<Client ID>' -Secret '<Secret>' -Tenant '<Tenant ID>'

# Change encryption schema

$encryptionChanges = @()

# Add changes for table [dbo].[Patients]
$encryptionChanges += New-SqlColumnEncryptionSettings -ColumnName dbo.Patients.SSN -EncryptionType Plaintext
$encryptionChanges += New-SqlColumnEncryptionSettings -ColumnName dbo.Patients.BirthDate -EncryptionType Plaintext

Set-SqlColumnEncryption -ColumnEncryptionSettings $encryptionChanges -InputObject $smoDatabase

