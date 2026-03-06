#Enabling SQL Server Ports
New-NetFirewallRule -DisplayName "SQL Server TDS" -Direction Inbound –Protocol TCP –LocalPort 1433 -Action allow -Profile Domain,Private;
New-NetFirewallRule -DisplayName "SQL Server DAC (Dedicated Admin Connection)" -Direction Inbound –Protocol TCP –LocalPort 1434 -Action allow -Profile Domain,Private;
New-NetFirewallRule -DisplayName "SQL Server Browser" -Direction Inbound –Protocol UDP –LocalPort 1434 -Action allow -Profile Domain,Private;
New-NetFirewallRule -DisplayName "SQL Server Availability Groups" -Direction Inbound –Protocol TCP –LocalPort 5022 -Action allow -Profile Domain,Private;
