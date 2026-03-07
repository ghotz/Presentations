#
# Demo connecting through SMO
#
#region Load Assemblies
[System.Reflection.Assembly]::LoadWithPartialName( `
	"Microsoft.SqlServer.SMO") | Out-Null;
#endregion
#region Functions definition
function Get-SQLInstance($InstanceName, $Login, $Password)
{
	$SQLInstance = New-Object "Microsoft.SqlServer.Management.Smo.Server" `
							  $InstanceName;
	if ($Login -eq $null) {
		$SQLInstance.ConnectionContext.LoginSecure = $true;
	}
	else {
		$SQLInstance.ConnectionContext.LoginSecure = $false;
		$SQLInstance.ConnectionContext.Login = $Login;
		$SQLInstance.ConnectionContext.Password = $Password;
	};
	# Force connection to get an early error message
	$SQLInstance.ConnectionContext.Connect();
	return $SQLInstance;
};
#endregion
#region Main
#Parameters
$SQLServerInstanceName = "localhost\prod1";
cls;

#Get server object
$SQLInstance = Get-SQLInstance $SQLServerInstanceName;

#Read Errorlog
$SQLInstance.ReadErrorLog() | sort LogDate -Descending | select * -First 5

#Execute T-SQL Commands
$SQLInstance.Databases["master"].ExecuteNonQuery("CHECKPOINT;");

#endregion
