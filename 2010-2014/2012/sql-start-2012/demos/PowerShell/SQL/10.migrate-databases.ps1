#region Load Assemblies and Global Error Handling
[System.Reflection.Assembly]::LoadWithPartialName( `
	"Microsoft.SqlServer.SMO") | Out-Null;
[System.Reflection.Assembly]::LoadWithPartialName( `
	"Microsoft.SqlServer.SMOExtended") | Out-Null;

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

#region Event Handlers
$PercentCompleteHandler = `
	[Microsoft.SqlServer.Management.Smo.PercentCompleteEventHandler] `
	{ 
		Write-Host ([string]$_.Percent + " percent processed.");
	};
$CompleteHandler = `
	[Microsoft.SqlServer.Management.Common.ServerMessageEventHandler] `
	{
		Write-Host $_.Error.Message;
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
function DatabaseFullBackup ($SQLInstance, $DatabaseName, $BackupPath)
{
	$Backup = New-Object "Microsoft.SqlServer.Management.Smo.Backup";
	$Backup.Action = "Database";
	$Backup.Database = $DatabaseName;
	$Backup.Initialize = $true;
	$Backup.CopyOnly = $true;
	$Backup.Devices.AddDevice($BackupPath + "\" + $DatabaseName + ".bak" `
								, "File");

	$Backup.add_PercentComplete($PercentCompleteHandler);
	$Backup.add_Complete($CompleteHandler);

	$Backup.SqlBackup($SQLInstance)
};
function RestoreDatabaseFromFullBackup ($DestinationSQLInstance, $DatabaseName `
								, $BackupPath, $DataFilesPath, $LogFilesPath)
{
	$Restore = New-Object "Microsoft.SqlServer.Management.Smo.Restore";
	$Restore.FileNumber = 1;
	$Restore.Devices.AddDevice($BackupPath + "\" + $DatabaseName + ".bak"`
								, "File");

	foreach ($File in $Restore.ReadFileList($DestinationSQLInstance))
	{
		$NewFile = New-Object "Microsoft.SqlServer.Management.Smo.relocatefile";
		$NewFile.LogicalFileName = $File.LogicalName;
		
		#Primary Data File
		if	($File.FileID -eq 1 -and $DataFilesPath -ne "")
		{	
			$NewFile.PhysicalFileName = ($DataFilesPath + "\" + $DatabaseName `
											+ "_" + $File.LogicalName + ".mdf");
		}
		#Secondary Data File
		elseif	($File.Type -eq "D" -and $DataFilesPath -ne "")
		{	   
			$NewFile.PhysicalFileName = ($DataFilesPath + "\" + $DatabaseName`
											+ "_" + $File.LogicalName + ".ndf");
		}
		#Log File
		elseif	($File.Type -eq "L" -and $LogFilesPath -ne "")
		{
			$NewFile.PhysicalFileName = ($LogFilesPath + "\" + $DatabaseName `
											+ "_" + $File.LogicalName + ".ldf");
		};

		if ($NewFile.PhysicalFileName -ne $null) {
			[void]$Restore.RelocateFiles.add($Newfile);
		};
	};
	
	$Restore.Database = $DatabaseName;
	$Restore.ReplaceDatabase = $true;
	$Restore.NoRecovery = $false;
	$Restore.Action = "Database";

	$Restore.add_PercentComplete($PercentCompleteHandler);
	$Restore.add_Complete($CompleteHandler);

	$Restore.SqlRestore($DestinationSQLInstance); 
};
#endregion

#region Main
#Parameters
$SourceSQLInstanceName = "localhost\PROD1";
$DestinationSQLInstanceName = "localhost\PROD2";
cls;
$BackupPath = "C:\Temp\";

$DataFilesPath = "D:\Program Files\Microsoft SQL Server\MSSQL10_50.PROD2\MSSQL\DATA";
$LogFilesPath = "D:\Program Files\Microsoft SQL Server\MSSQL10_50.PROD2\MSSQL\DATA";

$DatabaseNames = "AdventureWorksLT", "AdventureWorksDW", "Northwind";

#Uncomment to add sqlcmd path
$env:Path += ";C:\Program Files\Microsoft SQL Server\100\Tools\Binn"

#Main
$SourceSQLInstance = Get-SQLInstance $SourceSQLInstanceName;
$DestinationSQLInstance = Get-SQLInstance $DestinationSQLInstanceName;

foreach ($DatabaseName in $DatabaseNames)
{
	Write-Host ("`nBackup database [" + $DatabaseName + "]");
	DatabaseFullBackup 	$SourceSQLInstance $DatabaseName $BackupPath;

	Write-Host ("`nRestore database [" + $DatabaseName + "]");
	RestoreDatabaseFromFullBackup 	$DestinationSQLInstance $DatabaseName `
									$BackupPath $DataFilesPath $LogFilesPath;

	Write-Host ("`nExecuting post-migration script for database ["`
				+ $DatabaseName + "]");
				
	$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path;

	sqlcmd.exe -S $DestinationSQLInstanceName `
		-i "$ScriptPath/10.post-migration-actions.sql" `
		-v DatabaseName=$DatabaseName `
		-o "$ScriptPath/post-migration.log";
};
#endregion
