# Rich security model, at the beginning, to learn disable it
Set-ExecutionPolicy -ExecutionPolicy Unrestricted

# Get familiar with common commands
dir C:\
ls C:\
echo "Hello World!"
echo "Hello World!" > c:\temp\test.txt
type c:\temp\test.txt
del c:\temp\test.txt

# Now let's explore a little bit more
Get-Command dir						# let's explore about the command: it's an alias!
Get-Command Get-ChildItem			# let's explore about this defined command: it's a cmdlet
Get-ChildItem C:\					# let's try to use the cmdlet directly, works the same
Get-Command ls						# what about ls? another alias...
Get-Alias -Definition Get-ChildItem	# how many of them do we have? another one: gci

# let's see how to get help
man									# another alias... this time for Get-Help
Get-Help dir						# let's see what we can do with dir
Get-Help dir -examples				# output some examples
dir C:\Windows\* -Include *.log		# find log files in Windows directory
