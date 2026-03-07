@ECHO OFF
ECHO Configuring Advanced Firewall rules for SQL Server connectivity
ECHO.

ECHO Configuring SQL Server Mirroring Endpoint (assuming 5022)
ECHO.
netsh advfirewall firewall add rule name="Microsoft SQL Server MIrroring" dir=in action=allow protocol=TCP localport=5022 profile=domain localip=any remoteip=any
ECHO.

PAUSE
