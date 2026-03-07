cls
remove-Variable -scope Global -name SqlServerMaximumChildItems
remove-Variable -scope Global -name SqlServerConnectionTimeout
remove-Variable -scope Global -name SqlServerIncludeSystemObjects
remove-Variable -scope Global -name SqlServerMaximumTabCompletion

Remove-PSSnapin SqlServerCmdletSnapin100
Remove-PSSnapin SqlServerProviderSnapin100
