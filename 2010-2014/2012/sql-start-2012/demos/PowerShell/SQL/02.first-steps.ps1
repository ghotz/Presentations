#
# First steps with the provider
#
cd SQLSERVER:
dir
cd SQL
dir
cd M6500
dir
cd PROD1
dir

#could have been done as
cd SQLSERVER:\SQL\M6500\PROD1

# Let's explore jobs
dir JobServer
dir JobServer\Jobs

# we want to see only jobs last run status
dir JobServer\Jobs | Get-Member
dir JobServer\Jobs | Select Name, LastRunOutcome

# we can filter it
dir JobServer\Jobs | ? { $_.LastRunOutcome -eq "failed" } | Select Name

# but let's see another example with databases
dir Databases

# we want to show only databases with recovery model FULL
# Recovery Model is only a label, let's explore the memm
dir Databases | Get-member

#let's try
dir Databases | ? { $_.RecoveryModel -eq "Full" } | Select Name

# doesn't work, let's see
dir Databases | % { $_.RecoveryModel.GetType() }
# wait a minute, what about LastRunOutcome?
dir JobServer\Jobs | % { $_.LastRunOutcome.GetType() }
# it's also an enumerator, but the underlying type is String, for RecoveryModel is a number
dir Databases | ? { $_.RecoveryModel -eq 1 } | Select Name
dir Databases | ? { $_.RecoveryModel.ToString() -eq "Full" } | Select Name

# or we can use enumerator's values
# cd SQLSERVER:\SQL\M6500\PROD1
dir Databases | ? { $_.RecoveryModel -eq [Microsoft.SqlServer.Management.Smo.RecoveryModel]::Full } | Select Name

# of course we may as well use T-SQL :)
Invoke-Sqlcmd "SELECT * FROM sys.databases WHERE recovery_model_desc = 'FULL';" | Format-Table -Property name, recovery_model_desc

# ok, so why do we see also system databases here and not in the other case?
# Get-ChildItem does not list system object in general unless you use -Force
dir Databases -Force | ? { $_.RecoveryModel -eq 1 }

#
# Using Invoke-SqlCmd
#
Get-Help Invoke-Sqlcmd -Parameter *
Get-Help Invoke-Sqlcmd -Examples

# Example5
Invoke-Sqlcmd -Query "PRINT N'abc'"
# no output, we have to add -Verbose
Invoke-Sqlcmd -Query "PRINT N'abc'" -Verbose

#
# Using encoding/decoding cmdlets
#

# Quick example from BOL for table names
Encode-SqlName "Table:Test"
Decode-SqlName "Table%3ATest"

# Another example
dir "SQLSERVER:\SQLRegistration\Database Engine Server Group\Demos" | Select DisplayName
# How do we get to the correct Item? It has an \ in the name
$Instance = Get-Item ("SQLSERVER:\SQLRegistration\Database Engine Server Group\Demos\" + (Encode-SqlName "localhost\prod1"))
$Instance.ConnectionString

# Last example with SMO URNs
Convert-UrnToPath -Urn "Server[@Name='localhost\prod1']/Database[@Name='AdventureWorks']/Table[@Name='Address' and @Schema= 'Person']" 
dir (Convert-UrnToPath -Urn "Server[@Name='localhost\prod1']/Database[@Name='AdventureWorks']/Table[@Name='Address' and @Schema= 'Person']")

#
# Many methods to do the same things
#

#Example 1 using the provider
dir SQLSERVER:\SQL\M6500\PROD1\JobServer\Jobs | ? { $_.LastRunOutcome -eq "Failed" } | Select Name;

#Example 2 using SMO directly
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null;
$SQLInstance = New-Object "Microsoft.SqlServer.Management.Smo.Server" "localhost\prod1";
$SQLInstance.JobServer.Jobs | ? { $_.LastRunOutcome -eq "Failed" } | Select Name;

#Example 3 using SQLPSX 
#get-module -listAvailable
#import-module Agent;
Import-Module SQLPSX
Get-AgentJob "localhost\prod1" | ? { $_.LastRunOutcome -eq "Failed" }  | Select Name;
Remove-Module SQLPSX
