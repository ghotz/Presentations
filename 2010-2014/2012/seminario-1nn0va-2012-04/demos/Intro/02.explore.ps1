# First of all comments can be on one-line
<#
	or they can be
	multi-line
#>

#
# Constants and calculations
#
(100 + 100) * 2

# admin friendly
1kb
1mb
1gb
(1024 * 1024) / 1mb

# added in PowerShell 2
1tb
1pb

#
# Simple system cmdlets
#
Get-Process						# returns system processes (see F1)
Get-Service						# returns services

#
# Variables
#
$a = 1
$a

# assign results from a cmdlet
$proc = Get-Process
$proc[1]
$proc[2]
$proc[3]

#
# Piping commands
#
ps | Sort -desc ws | Select -first 3

# that was a shortcut for 
Get-Process | Sort-Object -Descending ws | Select-Object -first 3

# check aliases (note output is collapsed in one set)
Get-Alias -Definition Get-Process
Get-Alias -Definition Sort-Object
Get-Alias -Definition Select-Object

# we may as well stream directly the array
$proc | Sort -desc ws | Select -first 3

#
# Wrapping commands
#
Get-Process |
	Sort -Descending ws |
	Select -first 3

Get-Process `
	| Sort -Descending ws `
	| Select -first 3

#
# Discoverability
#
Get-Process | Get-Member		# discover object type and members

Get-Process | Get-Member -MemberType Properties

# select only interesting properties
Get-Process |
	Sort -Descending ws |
	Select Handles, ws, Id, ProcessName, Company -first 3

# fix the format
Get-Process |
	Sort -Descending ws |
	Select Handles, ws, Id, ProcessName, Company -first 3 |
	Format-Table

# what about WS(K)? Look at cmdlet examples...
Get-Process |
	Sort -Descending ws |
	Select	Handles,
			@{Label="WS(K)";Expression={[int]($_.WS/1024)}},
			Id, ProcessName, Company -first 3 |
	Format-Table

#
# Filtering
#

# let's check services properties
Get-Service | Get-Member -MemberType Properties

# get all running services
Get-Service | Where { $_.Status -eq "Running" }

# get running service related to SQL Server and simulate stop
Get-Service |
	Where { $_.Status -eq "Running" -and $_.DisplayName -match "SQL Server" } |
	Stop-Service -WhatIf

# compact form
gsv | ? { $_.Status -eq "Running" }

#
# Control Flow Elements
#

# Using the while loop
$i=0
while ($i++ -lt 10) { if ($i % 2) {"$i is odd"}}

# Using the foreach loop and the range operator
foreach ($i in 1..10) { if ($i % 2) {"$i is odd"}}

# Using the ForEach-Object cmdlet
1..10 | foreach { if ($_ % 2) {"$_ is odd"}}
