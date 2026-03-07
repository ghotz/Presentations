
cls;
$Queries = Get-Content -Delimiter "--" -Path "C:\Users\Gianluca\OneDrive\Documents\Presentations\UGISS\20170201 Technical Cloud Day 2017\Demos\advqueries.sql"
$Iterations = 1000;

$connectionString = "Server=tcp:" + "azuredbdemo" + ".database.windows.net" + ",1433;Initial Catalog=" + "AzureDemoDB02" + ";Persist Security Info=False;User ID=ghotz;Password=Passw0rd!" + ";MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString
$connection.Open()

while($Iterations-- -gt 0) 
{ 
    try
    {
        $Query = Get-Random -InputObject $Queries;
        Write-Output "Executing random query";
        $command = New-Object System.Data.SQLClient.SQLCommand($Query, $connection);
        $command.ExecuteNonQuery() | Out-Null;
        $Command.Dispose();
        Start-Sleep -Milliseconds 500;
    }
    catch
    {
        Write-Output "Error while executing query";
        $connection.Close();
        $connection.Open();
    }
}
$connection.Close()
