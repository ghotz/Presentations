@echo off

REM check for elevated privileges
REM credits: http://social.technet.microsoft.com/Forums/en/ITCG/thread/37dcfc4d-2c87-43ec-b992-eff148097606
whoami /groups | find "S-1-16-12288" > nul

if "%errorlevel%"=="0" (
	REM More info http://blogs.msdn.com/b/sql_pfe_blog/archive/2013/04/23/identifying-cause-of-sql-server-io-bottleneck-using-xperf.aspx

	xperf -on PROC_THREAD+LOADER+FLT_IO_INIT+FLT_IO+FLT_FASTIO+FLT_IO_FAILURE+FILENAME+FILE_IO+FILE_IO_INIT+DISK_IO+HARD_FAULTS+DPC+INTERRUPT+CSWITCH+PROFILE+DRIVERS+DISPATCHER -stackwalk MiniFilterPreOpInit+MiniFilterPostOpInit+CSWITCH+PROFILE+ThreadCreate+ReadyThread+DiskReadInit+DiskWriteInit+DiskFlushInit+FileCreate+FileCleanup+FileClose+FileRead+FileWrite -BufferSize 1024 -MaxBuffers 1024 -MaxFile 1024 -FileMode Circular
	echo Gathering data...
	pause
	xperf.exe -stop -d C:\temp\xperf\TestIO.etl
)	else (
	echo Not running as elevated user.
)

pause
