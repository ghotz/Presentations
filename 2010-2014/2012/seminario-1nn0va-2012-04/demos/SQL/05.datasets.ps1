#
# Demo connecting through SMO with general
# Error handling
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

#Get connection
$SQLInstance = Get-SQLInstance $SQLServerInstanceName;

#Create a table
$SQLInstance.Databases["tempdb"].ExecuteNonQuery(`
	"IF OBJECT_ID('dbo.T1', 'U') IS NOT NULL DROP TABLE dbo.T1;");
$SQLInstance.Databases["tempdb"].ExecuteNonQuery(`
	"CREATE TABLE dbo.T1 ( 
		field1 int not null primary key 
	,	field2 varchar(10) not null 
		); 
	");

#Insert some Data
for ( $i=1; $i -le 10; $i++ )
{
	$SQLInstance.Databases["tempdb"].ExecuteNonQuery(`
		"INSERT INTO dbo.T1 VALUES ($i, 'Value $i');");
};

#
#Select data with SMO
#
$SQLInstance.Databases["tempdb"].ExecuteWithResults(`
		"SELECT * FROM dbo.T1;");

#Strange output, let's get the object and see
$DataSet = $SQLInstance.Databases["tempdb"].ExecuteWithResults(`
		"SELECT * FROM dbo.T1;");

#It's a Dataset
$DataSet.GetType();

#So we can simply get to the rwos and stream them
$DataSet.Tables[0].Rows | Format-Table;
$DataSet.Tables[0].Rows | Sort field1 -Descending | Format-Table;

#
#Select data with SQL Server Provider
#
Invoke-Sqlcmd	-ServerInstance "localhost\prod1" `
				-Query "SELECT * FROM tempdb.dbo.T1;";

#Let's what type is returned
$DataSet = Invoke-Sqlcmd	-ServerInstance "localhost\prod1" `
				-Query "SELECT * FROM tempdb.dbo.T1;";

#It's an array of objects...
$DataSet.GetType();

#... DataRow objects
$DataSet[0].GetType();

#In the original command we specified the instance and the database
#this is another way of doing it
cd SQLSERVER:\SQL\M6500\PROD1\Databases\tempdb;
Invoke-Sqlcmd	"SELECT * FROM dbo.T1;"

#
#Select data with SQLPSX
#
Import-Module SQLPSX
Get-SqlData "localhost\prod1" "tempdb" "SELECT * FROM dbo.T1;";
Remove-Module SQLPSX
#endregion
