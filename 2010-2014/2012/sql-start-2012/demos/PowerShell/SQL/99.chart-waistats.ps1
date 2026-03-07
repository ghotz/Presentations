#
# Demo Chart Top Waistats based on
# http://blogs.technet.com/b/richard_macdonald/archive/2009/04/28/3231887.aspx
#
#region Load Assemblies
[System.Reflection.Assembly]::LoadWithPartialName( `
	"System.Windows.Forms") | Out-Null;
[System.Reflection.Assembly]::LoadWithPartialName( `
	"System.Windows.Forms.DataVisualization") | Out-Null;
#endregion

#region Main

# Get Waitstats data
$TopWaits = `
	Invoke-Sqlcmd	-ServerInstance "localhost\prod1" `
					-Query "SELECT * FROM sys.dm_os_wait_stats;" `
	|	where {$_.wait_type -like "*IO*"} `
	|	sort wait_time_ms `
	|	select * -Last 5;

$WaitTypes = @($TopWaits | % {$_.wait_type});
$WaitTimes = @($TopWaits | % {$_.wait_time_ms});

# create chart object 
$Chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart 
$Chart.Width = 500 
$Chart.Height = 400 
$Chart.Left = 40 
$Chart.Top = 30

# create a chartarea to draw on and add to chart 
$ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea 
$Chart.ChartAreas.Add($ChartArea)

# Add data to chart
[void]$Chart.Series.Add("Data");
$Chart.Series["Data"].Points.DataBindXY($WaitTypes, $WaitTimes);

# Find point with max/min values and change their colour 
$maxValuePoint = $Chart.Series["Data"].Points.FindMaxByValue() 
$maxValuePoint.Color = [System.Drawing.Color]::Red

$minValuePoint = $Chart.Series["Data"].Points.FindMinByValue() 
$minValuePoint.Color = [System.Drawing.Color]::Green

# change chart area colour 
$Chart.BackColor = [System.Drawing.Color]::Transparent

# make bars into 3d cylinders 
$Chart.Series["Data"]["DrawingStyle"] = "Cylinder"

# display the chart on a form 
$Chart.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right -bor 
                [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left 
$Form = New-Object Windows.Forms.Form 
$Form.Text = "PowerShell Chart" 
$Form.Width = 600 
$Form.Height = 600 
$Form.controls.add($Chart) 
$Form.Add_Shown({$Form.Activate()}) 
$Form.ShowDialog()

#Save the Chart
$Chart.SaveImage($Env:USERPROFILE + "\Desktop\Chart.png", "PNG")

#endregion
