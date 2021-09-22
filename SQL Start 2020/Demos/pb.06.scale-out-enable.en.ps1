<#
 Copyright:   2019 Gianluca Hotz
 License:     MIT License
              Permission is hereby granted, free of charge, to any
              person obtaining a copy of this software and associated
              documentation files (the "Software"), to deal in the
              Software without restriction, including without
              limitation the rights to use, copy, modify, merge,
              publish, distribute, sublicense, and/or sell copies of
              the Software, and to permit persons to whom the
              Software is furnished to do so, subject to the
              following conditions:
              The above copyright notice and this permission notice
              shall be included in all copies or substantial portions
              of the Software.
              THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
              ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
              LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
              FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
              EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
              FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
              AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
              OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
              OTHER DEALINGS IN THE SOFTWARE.
 Credits:    
#>
import-module sqlserver;

# Create a scale-out group
# PSQLMASTER.alphasys.local will be the head node
# need to restart DMS service after joining the group


1..2 | % {
        $SQLInstance = ("PSQLCOMPUTE{0:d2}" -f $_);
        Write-Host ("Adding $SQLInstance instance to scale-out head PSQLMASTER");
        Invoke-Sqlcmd `
            -ServerInstance $SQLInstance `
            -Query "EXEC sys.sp_polybase_join_group 'PSQLMASTER', 16450, 'MSSQLSERVER';";
        Get-Service -ComputerName $SQLInstance | ? { $_.Name -eq "SQLPBDMS" } | Restart-Service;
        };
