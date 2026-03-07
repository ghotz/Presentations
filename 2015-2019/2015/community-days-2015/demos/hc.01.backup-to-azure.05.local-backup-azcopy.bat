@echo off
"C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\azcopy.exe" /Source:C:\Temp\ /Dest:https://hcdemo.blob.core.windows.net/sqlbackups /Pattern:*.bak /XO /Y /BlobType:Page /Z:C:\Temp\azcopyjournal.txt /DestKey:<INSERT KEY HERE>
pause
