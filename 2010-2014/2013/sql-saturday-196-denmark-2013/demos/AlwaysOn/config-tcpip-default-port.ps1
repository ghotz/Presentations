[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") | out-null;

$InstanceName = 'MSSQLSERVER';

#Connect to the Instance 
$Server = new-object ('Microsoft.SqlServer.Management.Smo.WMI.ManagedComputer'); 
$Uri = "ManagedComputer[@Name='" + (get-item env:\computername).Value + "']/ServerInstance[@Name='" + $InstanceName + "']/ServerProtocol[@Name='Tcp']";
$tcp = $Server.GetSmoObject($Uri);

#Enable IP
$tcp.IsEnabled = $true;

##set specific port for IPALL
$Server.GetSmoObject($tcp.urn.Value + "/IPAddress[@Name='IPAll']").IPAddressProperties[1].Value = "1433";

#change settings
$tcp.Alter();

#restart service
if ($InstanceName -eq 'MSSQLSERVER')
{
	Restart-Service $InstanceName -Force;
}
else
{
	Restart-Service "MSSQL`$$InstanceName" -Force;
};	