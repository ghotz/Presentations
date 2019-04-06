#------------------------------------------------------------------------
#-- Copyright:   2018 Gianluca Hotz
#-- License:     MIT License
#--              Permission is hereby granted, free of charge, to any
#--              person obtaining a copy of this software and associated
#--              documentation files (the "Software"), to deal in the
#--              Software without restriction, including without
#--              limitation the rights to use, copy, modify, merge,
#--              publish, distribute, sublicense, and/or sell copies of
#--              the Software, and to permit persons to whom the
#--              Software is furnished to do so, subject to the
#--              following conditions:
#--              The above copyright notice and this permission notice
#--              shall be included in all copies or substantial portions
#--              of the Software.
#--              THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
#--              ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
#--              LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
#--              FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
#--              EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
#--              FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
#--              AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#--              OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
#--              OTHER DEALINGS IN THE SOFTWARE.
#--              This script needs to be run on the source system.
#-- Credits:    
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
