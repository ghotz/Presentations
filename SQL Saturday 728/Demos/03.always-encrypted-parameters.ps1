#------------------------------------------------------------------------
# Script:		always-encrypted-parameters
# Copyright:	2017 Gianluca Hotz
# License:		MIT License
# Credits:
#------------------------------------------------------------------------

$ConnectionString = "Data Source=localhost;Initial Catalog=Clinic;Column Encryption Setting=Enabled;User ID=ContosoClinicApplication;Password=Passw0rd1";
$Connection = New-Object System.Data.SqlClient.SqlConnection
$Connection.ConnectionString = $ConnectionString
$Connection.Open()

$Query = "SELECT * FROM Clinic.dbo.Patients WHERE SSN = @SSN; --b"
$Command = New-Object System.Data.SQLClient.SQLCommand($Query, $connection);
$Command.CommandType = [System.Data.CommandType]::Text;
$Command.Parameters.Add('@SSN', [System.Data.SqlDbType]::Char);
$Command.Parameters['@SSN'].Direction = [System.Data.ParameterDirection]::Input;
$Command.Parameters['@SSN'].Size = 11;
$Command.Parameters['@SSN'].Value = '795-73-9838';

$DataSet = New-Object System.Data.DataSet;
$DataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($Command);
[void]$DataAdapter.Fill($DataSet);

$DataSet.Tables;

$Connection.Close();
