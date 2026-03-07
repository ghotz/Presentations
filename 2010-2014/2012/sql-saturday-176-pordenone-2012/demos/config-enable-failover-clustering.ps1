Write-Host "Adding Failover Clustering feature";
Import-Module ServerManager;
Add-WindowsFeature Failover-Clustering;
