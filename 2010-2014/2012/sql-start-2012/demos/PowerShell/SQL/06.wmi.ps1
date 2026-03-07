#
# Demo get Disk space via WMI and buil a Graph
#
# WMI Win32_LogicalDisk DriveType
# 0 = Unknown
# 1 = No Root Directory
# 2 = Removable Disk
# 3 = Local Disk
# 4 = Network Drive
# 5 = Compact Disc
# 6 = RAM Disk
# From http://msdn.microsoft.com/en-us/library/aa394173(v=vs.85).aspx
#
# Graph Example
# http://blogs.technet.com/b/richard_macdonald/archive/2009/04/28/3231887.aspx
#

# Simple example
Get-WmiObject Win32_LogicalDisk | Format-Table

# Calculate sizes
Get-WmiObject Win32_LogicalDisk `
	| ? { $_.DriveType -eq 3 } `
	| Select DeviceID `
		,	 @{Name="DiskSizeGB";Expression={$_.Size/1GB}} `
		,	 @{Name="FreeSpaceGB";Expression={$_.FreeSpace/1GB}} `
		,	 @{Name="PercentageFree";Expression={($_.FreeSpace/$_.Size)*100}};
