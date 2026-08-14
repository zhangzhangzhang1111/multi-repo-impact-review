param(
  [string]$TaskRoot,
  [string]$Repo,
  [string]$Out,
  [string]$Report,
  [ValidateSet("auto", "git", "patch")][string]$Mode = "auto",
  [string]$Diff,
  [string]$Base,
  [string]$Head,
  [string]$ProjectId,
  [string]$Repository,
  [ValidateRange(1, 4)][int]$Depth = 2,
  [ValidateRange(1, 400)][int]$NodeBudget = 120,
  [ValidateRange(1, 100)][int]$TraceLimit = 30,
  [switch]$RebuildGraph
)

$ErrorActionPreference = "Stop"
$SkillDir = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$PackageRoot = if (Test-Path (Join-Path $SkillDir "project-packs\project-map.tsv")) { $SkillDir } else { [IO.Path]::GetFullPath((Join-Path $SkillDir "..\..")) }
$CbmLauncher = Join-Path $PackageRoot "runtime\launch-engine.ps1"
$ProjectMap = Join-Path $PackageRoot "project-packs\project-map.tsv"
$ReportTemplate = Join-Path $SkillDir "assets\report-template.md"
$Utf8 = [Text.UTF8Encoding]::new($false)

function Write-Utf8([string]$Path, [string]$Text) {
  [IO.File]::WriteAllText($Path, $Text, $Utf8)
}

function Invoke-Git([string[]]$Arguments) {
  $Value = & git @Arguments
  if ($LASTEXITCODE -ne 0) { throw "git failed: $($Arguments -join ' ')" }
  return $Value
}

function Invoke-Cbm([string[]]$Arguments, [string]$OutputFile) {
  $Previous = $env:CBM_LOG_LEVEL
  $env:CBM_LOG_LEVEL = "error"
  try {
    for ($Attempt = 1; $Attempt -le 3; $Attempt++) {
      $Value = & $CbmLauncher @Arguments
      if ($LASTEXITCODE -eq 0) {
        if ($OutputFile) { Write-Utf8 $OutputFile ((($Value | ForEach-Object { "$_" }) -join [Environment]::NewLine) + [Environment]::NewLine) }
        return @($Value)
      }
      if ($Attempt -lt 3) { Write-Warning "Graph query not ready; retrying ($Attempt/3)"; Start-Sleep -Seconds 1 }
    }
    throw "codebase-memory-mcp failed after 3 attempts: $($Arguments -join ' ')"
  } finally {
    $env:CBM_LOG_LEVEL = $Previous
  }
}

function Get-JsonProperty($Object, [string[]]$Names) {
  if ($null -eq $Object) { return $null }
  foreach ($Name in $Names) {
    $Property = $Object.PSObject.Properties[$Name]
    if ($Property -and "$($Property.Value)") { return "$($Property.Value)" }
  }
  return $null
}

function Normalize-RepositoryIdentity([string]$Value) {
  if (-not $Value) { return $Value }
  $Value = $Value.TrimEnd('/') -replace '\.git$', ''
  if ($Value -match '^[^@]+@([^:]+):(.+)$') { return "$($Matches[1])/$($Matches[2])" }
  if ($Value -match '^[a-zA-Z][a-zA-Z0-9+.-]*://(?:[^@/]+@)?(.+)$') { return $Matches[1] }
  return $Value
}

function Convert-UnifiedDiff([string]$Path, [string]$Source, [string]$BaseValue, [string]$HeadValue, [string]$OutputJson, [string]$ChangedList) {
  $Files = [Collections.Generic.List[object]]::new()
  $Current = $null
  $SawOldMarker = $false
  $SawNewMarker = $false
  function New-FileRecord {
    $Record = [ordered]@{ status = "modified"; oldPath = ""; path = ""; hunks = [Collections.Generic.List[object]]::new() }
    $Files.Add($Record)
    return $Record
  }
  function ConvertFrom-GitQuotedPath([string]$Value) {
    if (-not ($Value.StartsWith('"') -and $Value.EndsWith('"'))) { return $Value }
    $Value = $Value.Substring(1, $Value.Length - 2)
    $Bytes = [Collections.Generic.List[byte]]::new()
    for ($Index = 0; $Index -lt $Value.Length; $Index++) {
      $Character = $Value[$Index]
      if ($Character -ne '\' -or $Index -eq $Value.Length - 1) {
        $Bytes.AddRange([Text.Encoding]::UTF8.GetBytes([string]$Character))
        continue
      }

      if ($Index + 3 -lt $Value.Length) {
        $Octal = $Value.Substring($Index + 1, 3)
        if ($Octal -match '^[0-7]{3}$') {
          $Bytes.Add([Convert]::ToByte($Octal, 8))
          $Index += 3
          continue
        }
      }

      $Index++
      $Escaped = $Value[$Index]
      if ($Escaped -eq 'n') { $Bytes.Add(10) }
      elseif ($Escaped -eq 'r') { $Bytes.Add(13) }
      elseif ($Escaped -eq 't') { $Bytes.Add(9) }
      else { $Bytes.AddRange([Text.Encoding]::UTF8.GetBytes([string]$Escaped)) }
    }
    return [Text.Encoding]::UTF8.GetString($Bytes.ToArray())
  }
  function Clean-DiffPath([string]$Value) {
    $Value = ($Value -replace "`r$", "") -replace "`t.*$", ""
    $Value = ConvertFrom-GitQuotedPath $Value
    if ($Value -match '^[ab]/') { $Value = $Value.Substring(2) }
    return $Value
  }
  function Parse-Range([string]$Spec) {
    $Parts = $Spec.Split(',', 2)
    return [ordered]@{ start = [int]$Parts[0]; count = if ($Parts.Count -gt 1) { [int]$Parts[1] } else { 1 } }
  }

  foreach ($Line in [IO.File]::ReadLines($Path)) {
    if ($Line -match '^diff --git ("(?:\\.|[^"])*"|\S+) ("(?:\\.|[^"])*"|\S+)$') {
      $Current = New-FileRecord
      $SawOldMarker = $false
      $SawNewMarker = $false
      $Current.oldPath = Clean-DiffPath $Matches[1]
      $Current.path = Clean-DiffPath $Matches[2]
      continue
    }
    if ($Line.StartsWith("--- ")) {
      if ($null -eq $Current -or ($SawOldMarker -and $SawNewMarker)) {
        $Current = New-FileRecord
        $SawOldMarker = $false
        $SawNewMarker = $false
      }
      $Current.oldPath = Clean-DiffPath $Line.Substring(4)
      $SawOldMarker = $true
      continue
    }
    if ($Line.StartsWith("+++ ")) {
      if ($null -eq $Current) {
        $Current = New-FileRecord
        $SawOldMarker = $false
        $SawNewMarker = $false
      }
      $Current.path = Clean-DiffPath $Line.Substring(4)
      $SawNewMarker = $true
      continue
    }
    if ($Line.StartsWith("new file mode ")) { if ($null -eq $Current) { $Current = New-FileRecord }; $Current.status = "added"; continue }
    if ($Line.StartsWith("deleted file mode ")) { if ($null -eq $Current) { $Current = New-FileRecord }; $Current.status = "deleted"; continue }
    if ($Line.StartsWith("rename from ")) { if ($null -eq $Current) { $Current = New-FileRecord }; $Current.oldPath = Clean-DiffPath $Line.Substring(12); $Current.status = "renamed"; continue }
    if ($Line.StartsWith("rename to ")) { if ($null -eq $Current) { $Current = New-FileRecord }; $Current.path = Clean-DiffPath $Line.Substring(10); $Current.status = "renamed"; continue }
    if ($Line -match '^@@ -([^ ]+) \+([^ ]+) @@ ?(.*)$') {
      if ($null -eq $Current) { $Current = New-FileRecord }
      $OldRange = Parse-Range $Matches[1]
      $NewRange = Parse-Range $Matches[2]
      $Current.hunks.Add([ordered]@{oldStart=$OldRange.start; oldCount=$OldRange.count; newStart=$NewRange.start; newCount=$NewRange.count; section=$Matches[3]})
    }
  }

  $Normalized = [Collections.Generic.List[object]]::new()
  foreach ($File in $Files) {
    if ($File.oldPath -eq "/dev/null") { $File.status = "added" }
    if ($File.path -eq "/dev/null") { $File.status = "deleted"; $File.path = $File.oldPath }
    if ($File.status -eq "modified" -and $File.oldPath -and $File.path -and $File.oldPath -ne $File.path) { $File.status = "renamed" }
    if ($File.path -and $File.path -ne "/dev/null") { $Normalized.Add($File) }
  }
  $Manifest = [ordered]@{schemaVersion=1; source=$Source; base=$BaseValue; head=$HeadValue; diffFile="changes.diff"; files=$Normalized}
  Write-Utf8 $OutputJson (($Manifest | ConvertTo-Json -Depth 10) + [Environment]::NewLine)
  [IO.File]::WriteAllLines($ChangedList, @($Normalized | ForEach-Object {$_.path} | Sort-Object -Unique), $Utf8)
}

function Resolve-PatchSourceRoot([string]$ConfiguredRoot, [string]$PatchFile) {
  $TemporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("impact-root-" + [Guid]::NewGuid())
  New-Item -ItemType Directory -Path $TemporaryRoot | Out-Null
  try {
    $TemporaryJson = Join-Path $TemporaryRoot "changes.json"
    $TemporaryList = Join-Path $TemporaryRoot "changed-files.txt"
    Convert-UnifiedDiff $PatchFile "patch" "" "" $TemporaryJson $TemporaryList
    $ChangedPaths = @(Get-Content $TemporaryList | Where-Object { $_ })
    $Children = @(Get-ChildItem -LiteralPath $ConfiguredRoot -Directory | Where-Object { -not $_.Name.StartsWith('.') })
    $VisibleFiles = @(Get-ChildItem -LiteralPath $ConfiguredRoot -File | Where-Object { -not $_.Name.StartsWith('.') })
    $Candidates = @([IO.DirectoryInfo](Get-Item -LiteralPath $ConfiguredRoot)) + $Children
    $Scores = foreach ($Candidate in $Candidates) {
      $Score = @($ChangedPaths | Where-Object { Test-Path -LiteralPath (Join-Path $Candidate.FullName $_) }).Count
      [pscustomobject]@{ root = $Candidate.FullName; score = $Score }
    }
    $Maximum = ($Scores | Measure-Object -Property score -Maximum).Maximum
    $Best = @($Scores | Where-Object { $_.score -eq $Maximum })
    if ($Maximum -gt 0 -and $Best.Count -gt 1) { throw "Patch paths match multiple source directories under $ConfiguredRoot; set sourceDirectory explicitly" }
    if ($Maximum -gt 0) { return [IO.Path]::GetFullPath($Best[0].root) }
    if ($Children.Count -eq 1 -and $VisibleFiles.Count -eq 0) { return [IO.Path]::GetFullPath($Children[0].FullName) }
    return [IO.Path]::GetFullPath($ConfiguredRoot)
  } finally {
    Remove-Item -Recurse -Force $TemporaryRoot
  }
}

$TaskConfig = $null
if ($TaskRoot) {
  $TaskRoot = [IO.Path]::GetFullPath($TaskRoot)
  $TaskJson = Join-Path $TaskRoot "task.json"
  if (Test-Path $TaskJson -PathType Leaf) { $TaskConfig = Get-Content -Raw $TaskJson | ConvertFrom-Json }
  if (-not $Repo) {
    $Repo = Get-JsonProperty $TaskConfig @("sourceDirectory", "source_directory")
    if (-not $Repo) { $Repo = "repo" }
    if (-not [IO.Path]::IsPathRooted($Repo)) { $Repo = Join-Path $TaskRoot $Repo }
  }
  if (-not $Out) { $Out = Join-Path $TaskRoot "codegraph" }
  if (-not $Report) { $Report = Join-Path $TaskRoot "report" }
  if (-not $Diff) {
    $Diff = Get-JsonProperty $TaskConfig @("diffFile", "diff_file")
    if (-not $Diff) { $Diff = "diff\changes.diff" }
    if (-not [IO.Path]::IsPathRooted($Diff)) { $Diff = Join-Path $TaskRoot $Diff }
  }
  if ($Mode -eq "auto") { $ConfiguredMode = Get-JsonProperty $TaskConfig @("changeMode", "change_mode"); if ($ConfiguredMode) { $Mode = $ConfiguredMode } }
  if (-not $Base) { $Base = Get-JsonProperty $TaskConfig @("baseRef", "base_ref", "baseCommit") }
  if (-not $Head) { $Head = Get-JsonProperty $TaskConfig @("headRef", "head_ref", "headCommit") }
  if (-not $ProjectId) { $ProjectId = Get-JsonProperty $TaskConfig @("projectId", "project_id") }
  if (-not $Repository) { $Repository = Get-JsonProperty $TaskConfig @("repository") }
}

if (-not $Repo) { throw "-TaskRoot or -Repo is required" }
if (-not $Out) { throw "-Out is required when -TaskRoot is not used" }
if (-not (Test-Path $Repo -PathType Container)) { throw "Source directory does not exist: $Repo" }
if (-not (Test-Path $CbmLauncher -PathType Leaf)) { throw "Missing bundled graph-engine launcher: $CbmLauncher" }
if (-not (Test-Path $ProjectMap -PathType Leaf)) { throw "Missing project routing map" }

$RepoRoot = [IO.Path]::GetFullPath($Repo)
$ConfiguredRepoRoot = $RepoRoot
if ($Mode -eq "auto") {
  if ($Diff -and (Test-Path $Diff -PathType Leaf) -and (Get-Item $Diff).Length -gt 0) { $Mode = "patch" }
  elseif (Test-Path (Join-Path $RepoRoot ".git") -PathType Container) { $Mode = "git" }
  else { throw "Auto mode found neither diff/changes.diff nor repo/.git" }
}
if (-not $Base) { $Base = "HEAD~1" }
if (-not $Head -or $Head -eq "WORKTREE") { $Head = "HEAD" }
if ($Mode -eq "patch" -and (-not $Diff -or -not (Test-Path $Diff -PathType Leaf) -or (Get-Item $Diff).Length -eq 0)) { throw "Patch mode requires a non-empty changes.diff" }
if ($Mode -eq "patch") { $RepoRoot = Resolve-PatchSourceRoot $RepoRoot $Diff }
if ($Mode -eq "git") {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "Git mode requires git" }
  $RepoRoot = [IO.Path]::GetFullPath(((Invoke-Git @("-C", $RepoRoot, "rev-parse", "--show-toplevel")) -join "").Trim())
}

$Out = [IO.Path]::GetFullPath($Out)
if ($Out.StartsWith($RepoRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Codegraph output must be outside repo/" }
if ($Out.StartsWith($ConfiguredRepoRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Codegraph output must be outside repo/" }
if (-not $Report) { $Report = Join-Path $Out "report" }
$Report = [IO.Path]::GetFullPath($Report)
New-Item -ItemType Directory -Force -Path $Out, $Report | Out-Null
$Shadow = Join-Path $Out "analysis-source"
if (Test-Path $Shadow) { throw "$Shadow already exists; use an empty codegraph directory" }
$SourceDiff = Join-Path $Out "changes.diff"
$ChangedFilesPath = Join-Path $Out "changed-files.txt"
$ChangesJson = Join-Path $Out "changes.json"
$BaseSha = ""
$HeadSha = ""
$Dirty = $false
$Remote = if ($Repository) { $Repository } else { "" }

if ($Mode -eq "git") {
  $BaseSha = ((Invoke-Git @("-C", $RepoRoot, "rev-parse", $Base)) -join "").Trim()
  $HeadSha = ((Invoke-Git @("-C", $RepoRoot, "rev-parse", $Head)) -join "").Trim()
  $CurrentSha = ((Invoke-Git @("-C", $RepoRoot, "rev-parse", "HEAD")) -join "").Trim()
  if (-not $Repository) { $RemoteValue = & git -C $RepoRoot remote get-url origin 2>$null; if ($LASTEXITCODE -eq 0) { $Remote = ($RemoteValue -join "").Trim() } }
  & git -C $RepoRoot diff --quiet; $Dirty = $LASTEXITCODE -ne 0
  & git -C $RepoRoot diff --cached --quiet; $Dirty = $Dirty -or $LASTEXITCODE -ne 0
  $Untracked = @(& git -C $RepoRoot ls-files --others --exclude-standard)
  $Dirty = $Dirty -or $Untracked.Count -gt 0
  if ($Dirty -and $HeadSha -ne $CurrentSha) { throw "A dirty worktree can only be reviewed at HEAD/WORKTREE" }
  Invoke-Git @("clone", "--quiet", "--no-hardlinks", "--no-checkout", $RepoRoot, $Shadow) | Out-Null
  Invoke-Git @("-C", $Shadow, "checkout", "--quiet", "--detach", $HeadSha) | Out-Null
  if ($Dirty) {
    $WorktreePatch = Join-Path $Out ".worktree.patch"
    Invoke-Git @("-C", $RepoRoot, "diff", "HEAD", "--binary", "--output=$WorktreePatch") | Out-Null
    if ((Test-Path $WorktreePatch) -and (Get-Item $WorktreePatch).Length -gt 0) { Invoke-Git @("-C", $Shadow, "apply", "--whitespace=nowarn", $WorktreePatch) | Out-Null }
    foreach ($File in $Untracked) {
      $Destination = Join-Path $Shadow $File
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
      Copy-Item -LiteralPath (Join-Path $RepoRoot $File) -Destination $Destination
      Invoke-Git @("-C", $Shadow, "add", "-N", "--", $File) | Out-Null
    }
  }
  $DiffLines = & git -C $Shadow diff --binary $BaseSha --
  if ($LASTEXITCODE -ne 0) { throw "Unable to generate Git diff" }
  Write-Utf8 $SourceDiff (($DiffLines -join [Environment]::NewLine) + [Environment]::NewLine)
  Convert-UnifiedDiff $SourceDiff "git" $BaseSha $HeadSha $ChangesJson $ChangedFilesPath
} else {
  New-Item -ItemType Directory -Path $Shadow | Out-Null
  Get-ChildItem -Force -LiteralPath $RepoRoot | Copy-Item -Destination $Shadow -Recurse -Force
  $OldGraph = Join-Path $Shadow ".codebase-memory"
  if (Test-Path $OldGraph) { Remove-Item -Recurse -Force $OldGraph }
  Copy-Item -LiteralPath $Diff -Destination $SourceDiff
  $PatchHash = (Get-FileHash -Algorithm SHA256 $SourceDiff).Hash.ToLowerInvariant().Substring(0, 12)
  $BaseSha = if ($Base -and $Base -ne "HEAD~1") { $Base } else { "unknown-base" }
  $HeadSha = if ($Head -and $Head -ne "HEAD") { $Head } else { "snapshot-$PatchHash" }
  Convert-UnifiedDiff $SourceDiff "patch" $BaseSha $HeadSha $ChangesJson $ChangedFilesPath
}
$Remote = Normalize-RepositoryIdentity $Remote

$ChangedFiles = @(Get-Content $ChangedFilesPath | Where-Object { $_ } | Sort-Object -Unique)
if ($ChangedFiles.Count -eq 0) { throw "No changed files could be parsed from $SourceDiff" }
$GitExclude = Join-Path $Shadow ".git\info\exclude"
if (Test-Path (Split-Path -Parent $GitExclude)) { Add-Content -Encoding UTF8 $GitExclude ".codebase-memory/" }

$MatchesList = @()
$IgnoreFiles = @()
$BestProject = $null
$ProjectDirectory = Split-Path -Leaf $RepoRoot
foreach ($Row in (Import-Csv -Delimiter "`t" -Path $ProjectMap)) {
  $MarkerOk = $true
  if ($Row.markers -ne "*") { foreach ($Marker in $Row.markers.Split(',')) { if (-not (Test-Path (Join-Path $RepoRoot $Marker))) { $MarkerOk = $false } } }
  if ($Mode -eq "git") {
    $IdentityOk = $Row.git_remote_glob -ne "-" -and $Remote -like $Row.git_remote_glob
  } else {
    $ProjectMatch = $Row.patch_project_glob -ne "-" -and $ProjectDirectory -like $Row.patch_project_glob
    $DiffMatch = $Row.patch_diff_glob -ne "-" -and @($ChangedFiles | Where-Object { $_ -like $Row.patch_diff_glob }).Count -gt 0
    $IdentityOk = $ProjectMatch -or $DiffMatch
  }
  if ($ProjectId -and $Row.kind -eq "project") { $IdentityOk = $Row.id -eq $ProjectId }
  if ($IdentityOk -and $MarkerOk) {
    $MatchesList += [ordered]@{kind=$Row.kind; id=$Row.id; priority=[int]$Row.priority; knowledge=$Row.knowledge_file}
    if ($Row.cbmignore_file -and $Row.cbmignore_file -ne "-") { $IgnoreFiles += $Row.cbmignore_file }
    if ($Row.kind -eq "project" -and ($null -eq $BestProject -or [int]$Row.priority -gt [int]$BestProject.priority)) { $BestProject = $Row }
  }
}
if ($ProjectId -and ($null -eq $BestProject -or $BestProject.id -ne $ProjectId)) { throw "Project pack '$ProjectId' did not match its required marker files" }

$Detection = [ordered]@{schemaVersion=4; changeMode=$Mode; configuredRoot=$ConfiguredRepoRoot; root=$RepoRoot; projectDirectory=$ProjectDirectory; analysisRoot=$Shadow; repository=$Remote; head=$HeadSha; matches=$MatchesList}
Write-Utf8 (Join-Path $Out "project-detection.json") (($Detection | ConvertTo-Json -Depth 8) + [Environment]::NewLine)
if ($IgnoreFiles.Count -gt 0) {
  $IgnoreContent = foreach ($IgnoreFile in $IgnoreFiles) {
    $Full = Join-Path $PackageRoot $IgnoreFile
    if (-not (Test-Path $Full -PathType Leaf)) { throw "Missing configured cbmignore: $IgnoreFile" }
    Get-Content $Full
  }
  [IO.File]::WriteAllLines((Join-Path $Shadow ".cbmignore"), $IgnoreContent, $Utf8)
  $Exclude = Join-Path $Shadow ".git\info\exclude"
  if (Test-Path (Split-Path -Parent $Exclude)) { Add-Content -Encoding UTF8 $Exclude ".cbmignore" }
}

$RootHashBytes = [Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($RepoRoot))
$RootHash = ([BitConverter]::ToString($RootHashBytes).Replace('-', '').ToLowerInvariant()).Substring(0, 12)
$HeadShort = (($HeadSha -replace '[^A-Za-z0-9]', '-') + "snapshot").Substring(0, [Math]::Min(12, (($HeadSha -replace '[^A-Za-z0-9]', '-') + "snapshot").Length))
$RepoName = ((Split-Path -Leaf $RepoRoot) -replace '[^A-Za-z0-9._-]', '-')
$CbmProject = if ($BestProject) { "$($BestProject.id)-$HeadShort-$RootHash" } else { "$RepoName-$HeadShort-$RootHash" }

$PackagedGraph = $null
if ($Mode -eq "git" -and -not $RebuildGraph -and -not $Dirty -and $BestProject) {
  $Candidate = Join-Path $PackageRoot "project-packs\projects\$($BestProject.id)\codebase-memory\$HeadSha\graph.db.zst"
  if (Test-Path $Candidate -PathType Leaf) { New-Item -ItemType Directory -Force -Path (Join-Path $Shadow ".codebase-memory") | Out-Null; Copy-Item $Candidate (Join-Path $Shadow ".codebase-memory\graph.db.zst"); $PackagedGraph = $Candidate }
}

Invoke-Cbm @("cli", "index_repository", "--repo-path", $Shadow, "--mode", "full", "--name", $CbmProject, "--persistence", "true") (Join-Path $Out "index-result.json") | Out-Null
Invoke-Cbm @("cli", "get_graph_schema", "--project", $CbmProject) (Join-Path $Out "schema.json") | Out-Null
Invoke-Cbm @("cli", "index_status", "--project", $CbmProject) (Join-Path $Out "index-status.json") | Out-Null
if ($Mode -eq "git") {
  Invoke-Cbm @("cli", "detect_changes", "--project", $CbmProject, "--since", $BaseSha, "--direction", "inbound", "--depth", "$Depth", "--limit", "$NodeBudget", "--format", "json") (Join-Path $Out "official-impact-review.json") | Out-Null
  Write-Utf8 (Join-Path $Out "impact-review.json") "{`"schemaVersion`":1,`"changeSource`":`"git`",`"strategy`":`"official-detect_changes-plus-ai-verification`",`"officialResult`":`"official-impact-review.json`"}`n"
} else {
  Write-Utf8 (Join-Path $Out "impact-review.json") "{`"schemaVersion`":1,`"changeSource`":`"patch`",`"strategy`":`"diff-hunks-plus-search_graph-plus-bounded-trace_path`",`"requiresAiTrace`":true,`"reason`":`"detect_changes requires Git history; current snapshot was indexed successfully`"}`n"
}

$Artifact = Join-Path $Shadow ".codebase-memory\graph.db.zst"
if (-not (Test-Path $Artifact -PathType Leaf)) { throw "Official graph artifact was not produced" }
Copy-Item $Artifact (Join-Path $Out "graph.db.zst")
if (Test-Path (Join-Path $Shadow ".codebase-memory\artifact.json")) { Copy-Item (Join-Path $Shadow ".codebase-memory\artifact.json") $Out }
Write-Utf8 (Join-Path $Out "engine-project.txt") "$CbmProject`n"

$CandidatesDir = Join-Path $Out "symbol-candidates"
New-Item -ItemType Directory -Force -Path $CandidatesDir | Out-Null
$Packet = [Text.StringBuilder]::new()
[void]$Packet.AppendLine("# AI verification packet`n")
[void]$Packet.AppendLine("- Change source: ``$Mode``")
[void]$Packet.AppendLine("- Graph engine: codebase-memory-mcp 0.10.2")
[void]$Packet.AppendLine("- Project: ``$CbmProject``")
[void]$Packet.AppendLine("- Effective depth: $Depth (hard maximum 4)")
[void]$Packet.AppendLine("- Per-trace row budget: $TraceLimit")
[void]$Packet.AppendLine("- Global unique-node budget: $NodeBudget")
[void]$Packet.AppendLine("- Packaged graph reused: $(if ($PackagedGraph) {$PackagedGraph} else {'no'})`n")
[void]$Packet.AppendLine("## Changed-file symbol candidates")
for ($Index = 0; $Index -lt $ChangedFiles.Count; $Index++) {
  $File = $ChangedFiles[$Index]
  $SafeName = ($File -replace '[/\\ :]', '-') -replace '[^A-Za-z0-9._-]', ''
  if (-not $SafeName) { $SafeName = "file" }
  $Prefix = "{0:D3}-$SafeName" -f ($Index + 1)
  $CandidateFile = Join-Path $CandidatesDir "$Prefix.json"
  $CoverageFile = Join-Path $CandidatesDir "$Prefix-coverage.json"
  Invoke-Cbm @("cli", "search_graph", "--project", $CbmProject, "--file-pattern", $File, "--limit", "$TraceLimit", "--format", "json") $CandidateFile | Out-Null
  Invoke-Cbm @("cli", "check_index_coverage", "--project", $CbmProject, "--paths", $File) $CoverageFile | Out-Null
  [void]$Packet.AppendLine("`n### ``$File`` `n")
  [void]$Packet.AppendLine("- Symbol candidates: ``symbol-candidates/$([IO.Path]::GetFileName($CandidateFile))``")
  [void]$Packet.AppendLine("- Coverage: ``symbol-candidates/$([IO.Path]::GetFileName($CoverageFile))``")
}
[void]$Packet.AppendLine(@'

## Required AI action

1. Map each diff hunk in `changes.json` to the smallest current symbol that contains its new-line range. For deleted code, inspect the old side of `changes.diff` and mark the symbol deleted when it no longer exists in the snapshot.
2. For each prioritized changed symbol, call `trace_path` at depth 1 with `include_evidence=true`; expand one level at a time only while within the recorded budgets.
3. Read the cited source bodies and verify every retained edge. Add missing callback, configuration, function-pointer, macro, metatable, dynamic module, and C/C++-Lua binding edges.
4. Load the matched knowledge files from `project-detection.json`; use them only to interpret verified source facts.
5. Replace the draft under `report/review-report.md` with the human-facing result.
'@)
Write-Utf8 (Join-Path $Out "verification-packet.md") $Packet.ToString()

$Metadata = [ordered]@{
  schemaVersion=4; engine=[ordered]@{name="codebase-memory-mcp"; version="0.10.2"; license="MIT"}; changeMode=$Mode
  configuredSourceRoot=$ConfiguredRepoRoot; sourceRoot=$RepoRoot; projectDirectory=$ProjectDirectory; analysisRoot=$Shadow; project=$CbmProject; base=$BaseSha; head=$HeadSha
  requestedDepth=$Depth; effectiveDepth=$Depth; hardDepthLimit=4; perTraceRowBudget=$TraceLimit; globalUniqueNodeBudget=$NodeBudget
  graphArtifact="graph.db.zst"; targetRepositoryModified=$false
}
Write-Utf8 (Join-Path $Out "analysis-metadata.json") (($Metadata | ConvertTo-Json -Depth 8) + [Environment]::NewLine)
$Summary = @("# Deterministic pre-review summary", "", "- Change source: $Mode", "- Engine: codebase-memory-mcp 0.10.2 (MIT)", "- Base: ``$BaseSha``", "- Head/snapshot: ``$HeadSha``", "- Changed files: $($ChangedFiles.Count)", "- Traversal: depth $Depth, per trace $TraceLimit rows, global $NodeBudget unique nodes", "- AI source verification and final report: required") -join [Environment]::NewLine
Write-Utf8 (Join-Path $Out "summary.md") ($Summary + [Environment]::NewLine)
if (-not (Test-Path (Join-Path $Report "review-report.md"))) { Copy-Item $ReportTemplate (Join-Path $Report "review-report.md") }
Write-Host "OK: $Mode review evidence written to $Out"
Write-Host "NEXT: AI must verify call paths and complete $(Join-Path $Report 'review-report.md')"
