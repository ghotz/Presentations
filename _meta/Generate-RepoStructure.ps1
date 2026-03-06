<#
.SYNOPSIS
  Generates the Presentations repo directory structure and README files
  from _meta/events.csv, _meta/talks.csv, and _meta/authors.csv.

.DESCRIPTION
  - Creates bucket/year/kebab-title directories with /demos subdir
  - Generates a README.md per event with talk links
  - Generates a README.md per year-range bucket (e.g. 2020-2024)
  - Generates a README.md per year (e.g. 2020-2024/2023)
  - Generates the root README.md with indexes by year and by series
  - Updates events.csv with event_repo and demo_url GitHub URLs
  - Warns on 404 links and attempts archive.org Wayback fallback

.PARAMETER RepoRoot
  Path to the repo root. Defaults to the parent of the script directory.

.PARAMETER GitHubRepo
  GitHub repo slug (owner/repo). Used to build event_repo and demo_url.

.PARAMETER Branch
  Git branch name. Defaults to "master".

.PARAMETER SkipLinkCheck
  Skip HTTP 404 checking on all URLs.

.EXAMPLE
  .\Generate-RepoStructure.ps1 -WhatIf
  .\Generate-RepoStructure.ps1
  .\Generate-RepoStructure.ps1 -SkipLinkCheck
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter()]
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,

  [string]$GitHubRepo = "ghotz/Presentations",

  [string]$Branch = "master",

  [switch]$SkipLinkCheck
)

$ErrorActionPreference = "Stop"

$GitHubBase = "https://github.com/$GitHubRepo/tree/$Branch"

# ── Load CSVs ────────────────────────────────────────────────────────────────

$metaDir    = Join-Path $RepoRoot "_meta"
$eventsCsv  = Join-Path $metaDir "events.csv"
$talksCsv   = Join-Path $metaDir "talks.csv"
$authorsCsv = Join-Path $metaDir "authors.csv"

if (-not (Test-Path $eventsCsv))  { throw "Missing: $eventsCsv" }
if (-not (Test-Path $talksCsv))   { throw "Missing: $talksCsv" }
if (-not (Test-Path $authorsCsv)) { throw "Missing: $authorsCsv" }

$events  = Import-Csv $eventsCsv
$talks   = Import-Csv $talksCsv
$authors = Import-Csv $authorsCsv

# ── Validate required columns ────────────────────────────────────────────────

function Assert-Columns([object[]]$Data, [string[]]$Required, [string]$FileName) {
  if ($Data.Count -eq 0) { throw "$FileName is empty" }
  $cols = $Data[0].PSObject.Properties.Name
  foreach ($col in $Required) {
    if ($col -notin $cols) { throw "$FileName is missing required column: $col" }
  }
}

Assert-Columns $events  @('event_key','date','series','title','event_repo','demo_url') "events.csv"
Assert-Columns $talks   @('event_key','talk_title','author_keys')                     "talks.csv"
Assert-Columns $authors @('author_key','name')                                        "authors.csv"

# ── Index authors (kept for future use, not used in event READMEs) ───────────

$authorsByKey = @{}
foreach ($a in $authors) {
  $authorsByKey[$a.author_key.Trim()] = $a
}

# ── Index talks by event_key ─────────────────────────────────────────────────

$talksByEvent = @{}
foreach ($t in $talks) {
  $key = $t.event_key.Trim()
  if (-not $talksByEvent.ContainsKey($key)) { $talksByEvent[$key] = @() }
  $talksByEvent[$key] += $t
}

# ── Link checking with archive.org fallback ──────────────────────────────────

$checkedUrls = @{}

function Test-Url([string]$url) {
  if (-not $url -or $url.Trim() -eq "") { return $null }
  $url = $url.Trim()
  if ($checkedUrls.ContainsKey($url)) { return $checkedUrls[$url] }

  try {
    Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop | Out-Null
    $checkedUrls[$url] = $url
    return $url
  } catch {
    $status = $null
    if ($_.Exception.Response) {
      $status = [int]$_.Exception.Response.StatusCode
    }

    if ($status -eq 404 -or $status -eq 410) {
      Write-Warning "DEAD LINK ($status): $url"

      try {
        $wbApi = "https://archive.org/wayback/available?url=$([uri]::EscapeDataString($url))"
        $wbResp = Invoke-RestMethod -Uri $wbApi -TimeoutSec 10 -ErrorAction Stop
        if ($wbResp.archived_snapshots.closest.available -eq $true) {
          $archiveUrl = $wbResp.archived_snapshots.closest.url
          Write-Warning "  -> URL returned $status; substituted with archive.org snapshot: $archiveUrl"
          $checkedUrls[$url] = $archiveUrl
          return $archiveUrl
        }
      } catch {
        Write-Verbose "  -> Archive.org lookup failed for $url"
      }

      Write-Warning "  -> No archive.org fallback available for: $url"
      $checkedUrls[$url] = $null
      return $null
    } else {
      Write-Verbose "Link check inconclusive for ${url}: $($_.Exception.Message)"
      $checkedUrls[$url] = $url
      return $url
    }
  }
}

# ── Helpers ──────────────────────────────────────────────────────────────────

function Get-RangeBucket([int]$year) {
  $start = [int]([math]::Floor($year / 5.0) * 5)
  $end   = $start + 4
  return "{0:0000}-{1:0000}" -f $start, $end
}

function ConvertTo-Kebab([string]$s) {
  $s = $s.Trim().ToLowerInvariant()
  $s = $s -replace '[^a-z0-9-]', '-'
  $s = $s -replace '-{2,}', '-'
  $s = $s.Trim('-')
  if ([string]::IsNullOrWhiteSpace($s)) { throw "Empty kebab-case from title" }
  return $s
}

function Write-Utf8NoBom([string]$Path, [string]$Content) {
  $utf8 = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function HasValue([string]$s) {
  return ($null -ne $s) -and ($s.Trim() -ne "")
}

function Resolve-Url([string]$url) {
  if ($SkipLinkCheck) { return $url.Trim() }
  return Test-Url $url.Trim()
}

function Format-ExternalLink([string]$label, [string]$url) {
  $checked = Resolve-Url $url
  if ($null -eq $checked) {
    return "- ${label}: ~~<$($url.Trim())>~~ (offline)"
  }
  return "- ${label}: <${checked}>"
}

function Get-TalkSubList([string]$eventKey, [string]$indent) {
  $result = @()
  if ($talksByEvent.ContainsKey($eventKey)) {
    foreach ($t in $talksByEvent[$eventKey]) {
      $result += "${indent}- Talk: $($t.talk_title.Trim())"
    }
  }
  return $result
}

# ── Generate event directories and READMEs ───────────────────────────────────

$indexData    = @()
$csvModified  = $false

foreach ($e in $events) {
  $date   = [datetime]::ParseExact($e.date.Trim(), "yyyy-MM-dd", $null)
  $year   = $date.Year
  $bucket = Get-RangeBucket $year
  $kebab  = ConvertTo-Kebab $e.title

  $relPath    = "$bucket/$year/$kebab"
  $eventDir   = Join-Path $RepoRoot (Join-Path $bucket (Join-Path "$year" $kebab))
  $demoDir    = Join-Path $eventDir "demos"

  $eventRepoUrl = "$GitHubBase/$relPath"
  $demoUrl      = "$GitHubBase/$relPath/demos"

  # Update CSV fields if changed
  if ($e.event_repo -ne $eventRepoUrl) {
    $e.event_repo = $eventRepoUrl
    $csvModified = $true
  }
  if ($e.demo_url -ne $demoUrl) {
    $e.demo_url = $demoUrl
    $csvModified = $true
  }

  # Create event directory
  if ($PSCmdlet.ShouldProcess($eventDir, "Create directory")) {
    New-Item -ItemType Directory -Force -Path $eventDir | Out-Null
  }

  # Always create demos directory
  if ($PSCmdlet.ShouldProcess($demoDir, "Create demos directory")) {
    New-Item -ItemType Directory -Force -Path $demoDir | Out-Null
    $gitkeep = Join-Path $demoDir ".gitkeep"
    if (-not (Test-Path $gitkeep)) {
      Set-Content -Path $gitkeep -Value "" -Encoding ASCII
    }
  }

  # Build event README — always overwritten
  $readmePath = Join-Path $eventDir "README.md"

  $lines = [System.Collections.Generic.List[string]]::new()

  $lines.Add("# $($e.title.Trim())")
  $lines.Add("")

  if (HasValue $e.event_site) {
    $lines.Add((Format-ExternalLink "Event site" $e.event_site))
    $lines.Add("")
  }

  $eventKey = $e.event_key.Trim()
  if ($talksByEvent.ContainsKey($eventKey)) {
    foreach ($t in $talksByEvent[$eventKey]) {

      $lines.Add("## $($t.talk_title.Trim())")
      $lines.Add("")

      if (HasValue $t.slideshare) { $lines.Add((Format-ExternalLink "Slideshare" $t.slideshare)) }
      if (HasValue $t.youtube)    { $lines.Add((Format-ExternalLink "Youtube" $t.youtube)) }
      if (HasValue $t.vimeo)      { $lines.Add((Format-ExternalLink "Vimeo" $t.vimeo)) }

      $lines.Add("")
    }
  }

  $content = ($lines -join "`n").TrimEnd("`n") + "`n"

  if ($PSCmdlet.ShouldProcess($readmePath, "Write README.md")) {
    Write-Utf8NoBom -Path $readmePath -Content $content
  }

  # Collect for indexes
  $indexData += [PSCustomObject]@{
    Date     = $date
    Year     = $year
    Bucket   = $bucket
    Kebab    = $kebab
    EventKey = $e.event_key.Trim()
    Series   = $e.series.Trim()
    Title    = $e.title.Trim()
    RelPath  = $relPath
  }
}

# ── Write back events.csv with updated URLs ──────────────────────────────────

if ($csvModified) {
  if ($PSCmdlet.ShouldProcess($eventsCsv, "Update events.csv with event_repo and demo_url")) {
    $events | Export-Csv -Path $eventsCsv -NoTypeInformation -Encoding UTF8
    Write-Host "Updated events.csv with repo URLs." -ForegroundColor Yellow
  }
}

# ── Generate year-level READMEs ──────────────────────────────────────────────

$byBucketYear = $indexData | Group-Object { "$($_.Bucket)|$($_.Year)" }

foreach ($g in $byBucketYear) {
  $parts  = $g.Name -split '\|'
  $bucket = $parts[0]
  $year   = $parts[1]

  $yearDir    = Join-Path $RepoRoot (Join-Path $bucket $year)
  $yearReadme = Join-Path $yearDir "README.md"

  $lines = [System.Collections.Generic.List[string]]::new()

  $lines.Add("# $year")
  $lines.Add("")

  foreach ($e in ($g.Group | Sort-Object Title)) {
    $lines.Add("- [$($e.Title)]($($e.Kebab)/)")
    foreach ($talkLine in (Get-TalkSubList $e.EventKey "  ")) {
      $lines.Add($talkLine)
    }
  }
  $lines.Add("")

  $content = ($lines -join "`n").TrimEnd("`n") + "`n"

  if ($PSCmdlet.ShouldProcess($yearReadme, "Write year README.md")) {
    Write-Utf8NoBom -Path $yearReadme -Content $content
  }
}

# ── Generate bucket-level READMEs ────────────────────────────────────────────

$byBucket = $indexData | Group-Object Bucket

foreach ($g in $byBucket) {
  $bucket       = $g.Name
  $bucketDir    = Join-Path $RepoRoot $bucket
  $bucketReadme = Join-Path $bucketDir "README.md"

  $lines = [System.Collections.Generic.List[string]]::new()

  $lines.Add("# $bucket")
  $lines.Add("")

  $years = $g.Group | Group-Object Year | Sort-Object Name -Descending
  foreach ($yg in $years) {
    $lines.Add("## $($yg.Name)")
    $lines.Add("")

    foreach ($e in ($yg.Group | Sort-Object Title)) {
      $lines.Add("- [$($e.Title)]($($e.Year)/$($e.Kebab)/)")
      foreach ($talkLine in (Get-TalkSubList $e.EventKey "  ")) {
        $lines.Add($talkLine)
      }
    }
    $lines.Add("")
  }

  $content = ($lines -join "`n").TrimEnd("`n") + "`n"

  if ($PSCmdlet.ShouldProcess($bucketReadme, "Write bucket README.md")) {
    Write-Utf8NoBom -Path $bucketReadme -Content $content
  }
}

# ── Generate root README ─────────────────────────────────────────────────────

$root = [System.Collections.Generic.List[string]]::new()

$root.Add("# Presentations")
$root.Add("")
$root.Add("Slides and demo files from my sessions.")
$root.Add("Event folders are generated from ``_meta/events.csv`` and ``_meta/talks.csv``.")
$root.Add("")

# --- By year ---
$root.Add("## By year")
$root.Add("")

$byYear = $indexData | Sort-Object Date -Descending | Group-Object Year | Sort-Object { [int]$_.Name } -Descending
foreach ($g in $byYear) {
  $root.Add("### $($g.Name)")
  $root.Add("")
  foreach ($e in $g.Group | Sort-Object Date -Descending) {
    $dateStr = $e.Date.ToString("yyyy-MM-dd")
    $root.Add("- **$dateStr** [$($e.Title)]($($e.RelPath)/)")
  }
  $root.Add("")
}

# --- By series ---
$root.Add("## By series")
$root.Add("")

$bySeries = $indexData | Sort-Object Series, { $_.Date } -Descending | Group-Object Series
foreach ($g in ($bySeries | Sort-Object Name)) {
  $root.Add("### $($g.Name)")
  $root.Add("")
  foreach ($e in $g.Group | Sort-Object Date -Descending) {
    $dateStr = $e.Date.ToString("yyyy-MM-dd")
    $root.Add("- **$dateStr** [$($e.Title)]($($e.RelPath)/)")
  }
  $root.Add("")
}

$rootReadme = Join-Path $RepoRoot "README.md"
$rootContent = ($root -join "`n").TrimEnd("`n") + "`n"

if ($PSCmdlet.ShouldProcess($rootReadme, "Write root README.md")) {
  Write-Utf8NoBom -Path $rootReadme -Content $rootContent
}

Write-Host "Done. Generated $($indexData.Count) event(s)." -ForegroundColor Green
