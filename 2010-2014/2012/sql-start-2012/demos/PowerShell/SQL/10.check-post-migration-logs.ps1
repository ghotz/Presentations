#region Regex search string definitions
$SearchDBCC = [regex] ("CHECKDB found (?<AllocErr>\d*) allocation errors and "`
		+ "(?<ConsErr>\d*) consistency errors in database '(?<DBName>.*)'\.");

$SearchSQLError = [regex] ("Msg (?<ErrNum>\d*), Level (?<ErrLevel>\d*)"`
		+ ", State (?<ErrState>\d*), Server (?<ErrServer>.*)"`
		+ ", Line (?<ErrLine>\d*)\x0d\x0a(?<ErrMsg>.*)\x0d\x0a");
#endregion

cls;

$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path;

dir "$ScriptPath/*.log" |
	% {
		Write-Output "`n******************************************************";
		Write-Output "Searching for consistency/allocation errors in log $_"
		$TotalErrors = 0;
		$log = [io.file]::ReadAllText($_);

		$match = $SearchDBCC.Match($log);
		while ($match.Success) {
			if ($match.Groups['AllocErr'].Value -ne "0" `
				-or $match.Groups['ConsErr'].Value -ne "0") {
				
				Write-Output ("Database " + $match.Groups['DBName'].Value `
					+ " allocation errors " + $match.Groups['AllocErr'].Value `
					+ " consistency errors " + $match.Groups['ConsErr'].Value);

				$TotalErrors = [int]$match.Groups['AllocErr'].Value `
							 + [int]$match.Groups['ConsErr'].Value;
			};
			$match = $match.NextMatch();
		};

		Write-Output "******************************************************";
		Write-Output "`Searching for generic SQL Server errors in log $_"
		$match = $SearchSQLError.Match($log); 

		while ($match.Success) {
			Write-Output $match.Value;
			$TotalErrors++;
			$match = $match.NextMatch();
		};

		Write-Output "******************************************************";
		if ($TotalErrors -eq 0) {
			Write-Output "No errors found.";
		};
	};