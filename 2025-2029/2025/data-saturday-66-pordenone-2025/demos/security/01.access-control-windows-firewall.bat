@ECHO OFF
ECHO Configuring Advanced Firewall rules for SQL Server connectivity
ECHO.

ECHO Configuring SQL Server TDS port (assuming 1433)
ECHO.
netsh advfirewall firewall add rule name="Microsoft SQL Server" dir=in action=allow protocol=TCP localport=1433 profile=domain localip=any remoteip=any
ECHO.

ECHO Configuring SQL Server Dedicated Administrator Connection
ECHO.
netsh advfirewall firewall add rule name="Microsoft SQL Server DAC" dir=in action=allow protocol=TCP localport=1434 profile=domain localip=any remoteip=any
ECHO.

ECHO Configuring SQL Server Browser
ECHO.
netsh advfirewall firewall add rule name="Microsoft SQL Server Browser" dir=in action=allow protocol=UDP localport=1434 profile=domain localip=any remoteip=any
ECHO.

ECHO Configuring SQL Server Mirroring Endpoint (assuming 5022)
ECHO.
netsh advfirewall firewall add rule name="Microsoft SQL Server MIrroring" dir=in action=allow protocol=TCP localport=5022 profile=domain localip=any remoteip=any
ECHO.

PAUSE
