#
# Credits: examples adapted from PowerShell in Practice, Richard Siddaway, Manning
#

# Compare files
Compare -ReferenceObject compare1.txt -DifferenceObject compare2.txt
# Output the differences (change path)
Compare -ReferenceObject $(Get-Content compare1.txt) -DifferenceObject $(Get-Content compare2.txt)

# Count number of files per type
Get-ChildItem -Path "C:\Windows" |
	Where { !$_.PSIsContainer } |			# filter directories
	Group -Property Extension |
	Sort Count -Descending

# Get installed drives and output to grid
Get-PSDrive | Out-GridView

# Explore the Registry provider
cd HKLM:\SOFTWARE\Microsoft
dir "Microsoft SQL Server"
cd C:

# Get system event log records
Get-EventLog -LogName System |
	Where {$_.Timewritten -gt ((Get-Date).Adddays(-1))} 

# Using WMI to get computer information
Get-WmiObject -Class Win32_ComputerSystem |
	Format-List Name, SystemType, NumberOfProcessors

# Using WMI to get processor information
Get-WmiObject -Class Win32_Processor |
	Format-List Manufacturer, Name, Description, `
				ProcessorID, AddressWidth, DataWidth, `
				Family, MaxClockSpeed

# Using WMI to get free space on disk
Get-WmiObject win32_logicaldisk |
	sort -desc freespace |
	select -first 2 |
	format-table -autosize deviceid, freespace

# Using WMI to check hotfix
Get-WmiObject -Class Win32_QuickFixEngineering |
	? { $_.HotFixID -eq "KB2679255" }

# Working with environment
$env:Path
$env:Path += ";C:\temp"
