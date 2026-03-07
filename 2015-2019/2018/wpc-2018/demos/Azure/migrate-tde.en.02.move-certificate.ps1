# Use PowerShell console to copy certificate information from a pair of newly created files to a Personal Information Exchange (.pfx) file, using Pvk2Pfx tool
c:\utils\pvk2pfx.exe `
    -pvk C:\Temp\demos\TDEDemoCert.pvk `
    -pi "Passw0rd1" `
    -spc C:\Temp\demos\TDEDemoCert.cer `
    -pfx C:\Temp\demos\TDEDemoCert.pfx

# Export the certificate and private key to a Personal Information Exchange format
# certlm 

# Import the module into the PowerShell session
# Import-Module AzureRM
# Get-Module -Name AzureRM -List | select Name,Version
# Update-Module AzureRM

# Connect to Azure with an interactive dialog for sign-in
Connect-AzureRmAccount
# List subscriptions available and copy id of the subscription target Managed Instance belongs to
# Get-AzureRmSubscription
# Set subscription for the session (replace Guid_Subscription_Id with actual subscription id)
Select-AzureRmSubscription 'Microsoft Azure Sponsorship'

$fileContentBytes = Get-Content 'C:\Temp\demos\TDEDemoCert.pfx' -Encoding Byte
$base64EncodedCert = [System.Convert]::ToBase64String($fileContentBytes)
$securePrivateBlob = $base64EncodedCert  | ConvertTo-SecureString -AsPlainText -Force
$password = "Passw0rd1"
$securePassword = $password | ConvertTo-SecureString -AsPlainText -Force

Add-AzureRmSqlManagedInstanceTransparentDataEncryptionCertificate `
    -ResourceGroupName "AzureDemos" `
    -ManagedInstanceName "ugissmi" `
    -PrivateBlob $securePrivateBlob `
    -Password $securePassword
