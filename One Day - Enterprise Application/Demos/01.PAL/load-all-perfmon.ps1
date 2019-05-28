dir *.blg | % { relog.exe "$_" -f SQL -o "SQL:Perfmon!$($_.BaseName)" }
pause
