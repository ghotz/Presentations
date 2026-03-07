@ECHO OFF
rem http://support.microsoft.com/kb/2494036 needs to be installed!
cluster.exe SQLCLUSTER node SQL3 /prop NodeWeight=0
PAUSE
