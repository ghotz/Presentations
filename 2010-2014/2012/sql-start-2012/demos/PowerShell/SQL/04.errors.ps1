#
# Demo Error Handling with SMO
#
#region Load Assemblies and Global Error Handling
[System.Reflection.Assembly]::LoadWithPartialName( `
	"Microsoft.SqlServer.SMO") | Out-Null;
# Simple global exception handling to see SQL Server errors
trap {
		$Exc = $_.Exception;
		while ( $Exc.InnerException )
		{
			$Exc = $Exc.InnerException;
			Write-Warning ("(generic trap) " + $Exc.Message);
		};
		break;
};
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

#Error get's trapped by the generic trap if you run the whole script.
$SQLInstance.Databases["master"].ExecuteNonQuery("CHECKPINT;");
#However, if you select and execute the statement, the trap is not defined.

# With Invoke-Sqlcmd you get at least something readable
Invoke-Sqlcmd -ServerInstance $SQLServerInstanceName -Query "CHECKPINT;";

#Doing proper error handling in SMO
try {
	$SQLInstance.Databases["master"].ExecuteNonQuery("CHECKPINT;");
}
catch
{
	$Exc = $_.Exception;
	while ( $Exc.InnerException )
	{
		$Exc = $Exc.InnerException;
		Write-Warning ("(generic trap) " + $Exc.Message);
	};
}
finally 
{
	#Do some cleanup here
};

#If you *really* don't need to handle errors, you can istruct SMO to continue
cls;
$SQLInstance.Databases["master"].ExecuteNonQuery("CHECKPINT;", [Microsoft.SqlServer.Management.Common.ExecutionTypes]::ContinueOnError);

#endregion
