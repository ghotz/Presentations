# Design: Presentations Repository Structure

## Overview

This repo contains slides and demo files from conference sessions spanning ~20 years.
A PowerShell script (`_meta/Generate-RepoStructure.ps1`) generates the directory tree
and all README.md files from CSV metadata.

## CSV files (in `_meta/`)

### events.csv

One row per event. The script reads all columns but only **writes back** `event_repo` and `demo_url`.

| Column | Required | Description | Example |
|---|---|---|---|
| `event_key` | yes | Unique key, used to join with talks.csv | `ds31` |
| `date` | yes | ISO date `yyyy-MM-dd` | `2023-02-25` |
| `series` | yes | Event series name (used for "By series" index) | `Data Saturday` |
| `title` | yes | Full event title — also drives the kebab-case directory name | `Data Saturday 31 Pordenone 2023` |
| `city` | no | City (CSV only, not shown in READMEs) | `Pordenone` |
| `country` | no | Country code (CSV only, not shown in READMEs) | `IT` |
| `event_format` | no | `virtual`, `in-person`, or `hybrid` (CSV only, not shown in READMEs) | `in-person` |
| `event_site` | no | URL to event page | `https://datasaturdays.com/Event/20230225-datasaturday0031` |
| `sessionize_url` | no | URL to the event on Sessionize | |
| `event_repo` | auto | **Written by script.** GitHub URL to event directory | |
| `demo_url` | auto | **Written by script.** GitHub URL to demos directory | |

### talks.csv

One row per talk. Multiple rows with the same `event_key` = multiple talks at that event.

| Column | Required | Description | Example |
|---|---|---|---|
| `event_key` | yes | FK to events.csv | `ds31` |
| `talk_title` | yes | Session title | `SQL Server 2022 Intelligent Query Processing` |
| `author_keys` | yes | JSON array of keys into authors.csv | `["ghotz"]` |
| `slideshare` | no | SlideShare URL | `https://www.slideshare.net/ghotz/sql-server-2022-intelligent-query-processing` |
| `youtube` | no | YouTube URL | `https://youtu.be/HGPjZkV3iqo` |
| `vimeo` | no | Vimeo URL | `https://vimeo.com/ugiss/sql2022iqp` |
| `sessionize_url` | no | URL to the session on Sessionize | |

Note: `author_keys` is a JSON array (e.g. `["ghotz","jdoe"]`) for future normalization when migrating to SQL Server. The script does **not** render authors in READMEs.

### authors.csv

Normalized author registry. Not directly used by the script today, but loaded and validated
for future use (e.g. other tooling that reads these CSVs).

| Column | Required | Description | Example |
|---|---|---|---|
| `author_key` | yes | Unique key | `ghotz` |
| `name` | yes | Display name | `Gianluca Hotz` |
| `site` | no | Personal website URL | |
| `linkedin` | no | LinkedIn profile URL | |

### slideshare-export.csv

Not used by the script. Kept for reference. Contains SlideShare analytics export with
columns `Presentation`, `Views`, `Downloads`, `Favorites`, `Comments`, `Email Shares`.
Titles may have duplicates (different uploads with the same name) and case variations.

## Directory structure

Three-level hierarchy: **range bucket → year → kebab-title**.

```
repo-root/
├── README.md                              ← root index (by year + by series, no talks)
├── _meta/
│   ├── Generate-RepoStructure.ps1
│   ├── events.csv
│   ├── talks.csv
│   ├── authors.csv
│   └── slideshare-export.csv
├── 2025-2029/
│   ├── README.md                          ← bucket index (by year descending, with talks)
│   ├── 2026/
│   │   ├── README.md                      ← year index (with talks)
│   │   └── data-saturday-80-pordenone-2026/
│   │       ├── README.md                  ← event detail
│   │       └── demos/
│   └── 2025/
│       ├── README.md
│       └── data-saturday-66-pordenone-2025/
│           ├── README.md
│           └── demos/
└── 2020-2024/
    └── ...
```

### Naming rules

- **Range bucket**: 5-year groups aligned to multiples of 5: `2000-2004`, `2005-2009`, ..., `2025-2029`
- **Year**: plain four digits: `2023`
- **Event directory**: kebab-case from `title` in events.csv
  - lowercase, non-alphanumeric characters replaced with `-`, collapsed, trimmed
  - `Data Saturday 31 Pordenone 2023` → `data-saturday-31-pordenone-2023`
- **Demos**: always `demos/` inside each event directory

## README content at each level

### Root (`README.md`)

- H1: `# Presentations`
- Intro paragraph
- H2: `## By year` — events grouped by year (**descending**), each entry:
  `- **2026-02-28** [Data Saturday 80 Pordenone 2026](2025-2029/2026/data-saturday-80-pordenone-2026/)`
- H2: `## By series` — events grouped by series name (alphabetical), same format
- **No talk sub-lists** at this level (too many)

### Bucket (`2020-2024/README.md`)

- H1: range label (e.g. `# 2020-2024`)
- H2 per year within the bucket (**descending** order)
- Events sorted alphabetically by title, with talk sub-list:
  ```
  - [Data Saturday 48 Pordenone 2024](2024/data-saturday-48-pordenone-2024/)
    - Talk: Multitenancy con SQL Server e Azure SQL Database
  - [WPC 2024](2024/wpc-2024/)
    - Talk: Azure Database Fleet Manager
  ```
- Links are **relative** (no absolute GitHub URLs)

### Year (`2020-2024/2023/README.md`)

- H1: year (e.g. `# 2023`)
- Events sorted alphabetically by title, with talk sub-list:
  ```
  - [Data Saturday 31 Pordenone 2023](data-saturday-31-pordenone-2023/)
    - Talk: SQL Server 2022 Intelligent Query Processing
  ```
- Links are **relative**

### Event (`2020-2024/2023/data-saturday-31-pordenone-2023/README.md`)

- H1: event title from CSV
- Event site and Sessionize URL as external links (if present)
- H2 per talk title
- Under each talk: slideshare/youtube/vimeo/sessionize links (only if present)
- If a talk has no links, just the H2 heading with a blank line after it
- **No author shown**
- External URLs wrapped in `<>` (e.g. `<https://...>`)
- Dead links shown as `~~<url>~~ (offline)`

Example:
```markdown
# Data Saturday 31 Pordenone 2023

- Event site: <https://datasaturdays.com/Event/20230225-datasaturday0031>

## SQL Server 2022 Intelligent Query Processing

- Slideshare: <https://www.slideshare.net/ghotz/sql-server-2022-intelligent-query-processing>
- Youtube: <https://youtu.be/HGPjZkV3iqo>
- Vimeo: <https://vimeo.com/ugiss/sql2022iqp>
```

## Markdown formatting rules

- Always a blank line after every heading (markdown lint MD022)
- External (non-local) URLs wrapped in angle brackets: `<https://...>`
- Local links as standard markdown: `[text](relative/path/)`
- All README files are UTF-8 without BOM
- All README files are always overwritten on every run

## Script behavior

### Parameters

| Parameter | Default | Description |
|---|---|---|
| `-RepoRoot` | parent of `_meta/` | Path to repo root |
| `-GitHubRepo` | `ghotz/Presentations` | Owner/repo slug for building URLs |
| `-Branch` | `master` | Branch name for GitHub URLs |
| `-SkipLinkCheck` | off | Skip HTTP HEAD checks on external URLs |

### CSV writeback

The script writes `event_repo` and `demo_url` back into `events.csv` with full GitHub URLs:

- `event_repo`: e.g. `https://github.com/ghotz/Presentations/tree/master/2020-2024/2023/data-saturday-31-pordenone-2023`
- `demo_url`: e.g. `https://github.com/ghotz/Presentations/tree/master/2020-2024/2023/data-saturday-31-pordenone-2023/demos`

These are absolute URLs intended for use by other tools (not used in READMEs).

### Link checking

When `-SkipLinkCheck` is **not** set:
1. Every external URL gets an HTTP HEAD request (10s timeout)
2. Results are cached per-URL within a run
3. On 404/410: outputs a `Write-Warning` with the status code and URL
4. If archive.org has a snapshot: replaces the URL in the README and outputs a
   warning noting the HTTP status and the archive.org substitute URL
5. If no snapshot: writes the URL as strikethrough with `(offline)`
6. Non-404 errors (timeout, SSL): keeps the original URL

### ShouldProcess

The script supports `-WhatIf` for dry runs. Directory creation, file writes, and CSV
updates are all gated behind `ShouldProcess`.

## Design decisions and rationale

- **No YAML frontmatter in READMEs**: the CSVs are the single source of truth; READMEs are
  pure markdown for readability on GitHub.
- **kebab-case from title**: removes the need for a separate `folder_name` column; the
  title is the only input needed to derive the directory name deterministically.
- **City/country/event_format only in CSV**: keeps README output clean; the event title usually
  already includes location info (e.g. "Pordenone 2023"). `event_format` tracks whether an
  event was `virtual`, `in-person`, or `hybrid`.
- **authors.csv loaded but not rendered**: the CSV ecosystem is shared with other tools;
  the script validates it but event READMEs don't show authors to keep them minimal.
- **`demos/` always created**: simplifies workflow — just drop files in, no need to
  create the directory manually.
- **Range buckets (5-year)**: keeps the repo root to ~6 directories instead of 20+ year
  folders, while the year level inside groups events naturally.
- **No `-Force` flag**: all READMEs are always regenerated from CSV truth. Manual edits
  to READMEs will be lost — by design.
