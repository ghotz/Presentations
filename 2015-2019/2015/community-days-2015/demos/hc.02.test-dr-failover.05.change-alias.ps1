#
# NOTE: this script requires Administrative privileges
#

# Switch alias to on-premise for 64bit clients
New-ItemProperty `
    -Path "HKLM:\SOFTWARE\Microsoft\MSSQLServer\Client\ConnectTo" `
    -Name "HCDEMO" `
    -PropertyType String `
    -Value  "DBMSSOCN,localhost,1433" `
    -Force;

# Switch alias to on-premise for 32bit clients
New-ItemProperty `
    -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\MSSQLServer\Client\ConnectTo" `
    -Name "HCDEMO" `
    -PropertyType String `
    -Value  "DBMSSOCN,localhost,1433" `
    -Force;

# Switch alias to Azure VM for 64bit clients
New-ItemProperty `
    -Path "HKLM:\SOFTWARE\Microsoft\MSSQLServer\Client\ConnectTo" `
    -Name "HCDEMO" `
    -PropertyType String `
    -Value  "DBMSSOCN,hcdrdemo.cloudapp.net,1433" `
    -Force;

# Switch alias to Azure VM for 32bit clients
New-ItemProperty `
    -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\MSSQLServer\Client\ConnectTo" `
    -Name "HCDEMO" `
    -PropertyType String `
    -Value  "DBMSSOCN,hcdrdemo.cloudapp.net,1433" `
    -Force;
