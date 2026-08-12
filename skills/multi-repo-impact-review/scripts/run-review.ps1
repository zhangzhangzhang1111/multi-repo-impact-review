param(
  [Parameter(Mandatory = $true)][string]$Repo,
  [string]$Base = "HEAD~1",
  [string]$Head = "HEAD",
  [Parameter(Mandatory = $true)][string]$Out,
  [ValidateRange(1, 4)][int]$Depth = 2,
  [ValidateRange(1, 400)][int]$NodeBudget = 120,
  [ValidateRange(1, 100)][int]$TraceLimit = 30,
  [switch]$RebuildGraph
)

$ErrorActionPreference = "Stop"
$SkillDir = Split-Path -Parent $PSScriptRoot
$PluginRoot = [IO.Path]::GetFullPath((Join-Path $SkillDir "..\.."))
$CbmLauncher = Join-Path $PluginRoot "runtime\launch-mcp.ps1"
$ProjectMap = Join-Path $PluginRoot "project-packs\project-map.tsv"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "Git is required" }
if (-not (Test-Path $CbmLauncher -PathType Leaf)) { throw "Missing bundled codebase-memory-mcp launcher" }

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
        if ($OutputFile) { [IO.File]::WriteAllText($OutputFile, (($Value -join [Environment]::NewLine) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false)) }
        return $Value
      }
      if ($Attempt -lt 3) {
        Write-Warning "codebase-memory-mcp query not ready; retrying ($Attempt/3)"
        Start-Sleep -Seconds 1
      }
    }
    throw "codebase-memory-mcp failed after 3 attempts: $($Arguments -join ' ')"
  } finally {
    $env:CBM_LOG_LEVEL = $Previous
  }
}

$RepoRoot = [IO.Path]::GetFullPath(((Invoke-Git @("-C", $Repo, "rev-parse", "--show-toplevel")) -join "").Trim())
$Out = [IO.Path]::GetFullPath($Out)
if ($Out.StartsWith($RepoRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Output must be outside the reviewed repository" }
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$Shadow = Join-Path $Out "analysis-source"
if (Test-Path $Shadow) { throw "Output already contains analysis-source; use a new output directory" }

$BaseSha = ((Invoke-Git @("-C", $RepoRoot, "rev-parse", $Base)) -join "").Trim()
$HeadSha = ((Invoke-Git @("-C", $RepoRoot, "rev-parse", $Head)) -join "").Trim()
$CurrentSha = ((Invoke-Git @("-C", $RepoRoot, "rev-parse", "HEAD")) -join "").Trim()
$RemoteResult = & git -C $RepoRoot remote get-url origin 2>$null
$Remote = if ($LASTEXITCODE -eq 0) { ($RemoteResult -join "").Trim() } else { $RepoRoot }

& git -C $RepoRoot diff --quiet
$Dirty = $LASTEXITCODE -ne 0
& git -C $RepoRoot diff --cached --quiet
$Dirty = $Dirty -or $LASTEXITCODE -ne 0
$Untracked = @(& git -C $RepoRoot ls-files --others --exclude-standard)
$Dirty = $Dirty -or $Untracked.Count -gt 0
if ($Dirty -and $HeadSha -ne $CurrentSha) { throw "Dirty worktree can only be reviewed with -Head HEAD/WORKTREE" }

Invoke-Git @("clone", "--quiet", "--no-hardlinks", "--no-checkout", $RepoRoot, $Shadow) | Out-Null
Invoke-Git @("-C", $Shadow, "checkout", "--quiet", "--detach", $HeadSha) | Out-Null

if ($Dirty) {
  $PatchFile = Join-Path $Out "worktree.patch"
  Invoke-Git @("-C", $RepoRoot, "diff", "HEAD", "--binary", "--output=$PatchFile") | Out-Null
  if ((Test-Path $PatchFile) -and (Get-Item $PatchFile).Length -gt 0) { Invoke-Git @("-C", $Shadow, "apply", "--whitespace=nowarn", $PatchFile) | Out-Null }
  [IO.File]::WriteAllLines((Join-Path $Out "untracked-files.txt"), $Untracked, [Text.UTF8Encoding]::new($false))
  foreach ($File in $Untracked) {
    if (-not $File) { continue }
    $Destination = Join-Path $Shadow $File
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
    Copy-Item -LiteralPath (Join-Path $RepoRoot $File) -Destination $Destination
  }
}

$Matches = @()
$IgnoreFiles = @()
$BestProject = $null
$Rows = Import-Csv -Delimiter "`t" -Path $ProjectMap
foreach ($Row in $Rows) {
  $MarkerOk = $true
  if ($Row.markers -ne "*") {
    foreach ($Marker in $Row.markers.Split(',')) { if (-not (Test-Path (Join-Path $RepoRoot $Marker))) { $MarkerOk = $false } }
  }
  $IdentityOk = (($Row.remote_glob -eq "*") -and ($Row.path_glob -eq "*")) -or
    (($Row.remote_glob -ne "*") -and ($Remote -like $Row.remote_glob)) -or
    (($Row.path_glob -ne "*") -and ($RepoRoot -like $Row.path_glob))
  if ($IdentityOk -and $MarkerOk) {
    $Matches += [ordered]@{kind=$Row.kind; id=$Row.id; priority=[int]$Row.priority; knowledge=$Row.knowledge_file}
    if ($Row.cbmignore_file -and $Row.cbmignore_file -ne "-") { $IgnoreFiles += $Row.cbmignore_file }
    if ($Row.kind -eq "project" -and ($null -eq $BestProject -or [int]$Row.priority -gt [int]$BestProject.priority)) { $BestProject = $Row }
  }
}

[ordered]@{schemaVersion=2; root=$RepoRoot; analysisRoot=$Shadow; remote=$Remote; commit=$HeadSha; matches=$Matches} |
  ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 (Join-Path $Out "project-detection.json")

if ($IgnoreFiles.Count -gt 0) {
  $IgnoreContent = foreach ($IgnoreFile in $IgnoreFiles) {
    $Full = Join-Path $PluginRoot $IgnoreFile
    if (-not (Test-Path $Full)) { throw "Missing configured cbmignore: $IgnoreFile" }
    Get-Content $Full
  }
  [IO.File]::WriteAllLines((Join-Path $Shadow ".cbmignore"), $IgnoreContent, [Text.UTF8Encoding]::new($false))
  Add-Content -Encoding UTF8 (Join-Path $Shadow ".git\info\exclude") ".cbmignore`n.codebase-memory/"
}

$HeadShort = $HeadSha.Substring(0, 12)
if ($BestProject) {
  $CbmProject = "$($BestProject.id)-$HeadShort"
} else {
  $HashBytes = [Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($RepoRoot))
  $RootHash = ([BitConverter]::ToString($HashBytes).Replace('-', '').ToLowerInvariant()).Substring(0, 12)
  $RepoName = ((Split-Path -Leaf $RepoRoot) -replace '[^A-Za-z0-9._-]', '-')
  $CbmProject = "$RepoName-$HeadShort-$RootHash"
}

$PackagedGraph = $null
if (-not $RebuildGraph -and -not $Dirty -and $BestProject) {
  $Candidate = Join-Path $PluginRoot "project-packs\projects\$($BestProject.id)\codebase-memory\$HeadSha\graph.db.zst"
  if (Test-Path $Candidate -PathType Leaf) {
    New-Item -ItemType Directory -Force -Path (Join-Path $Shadow ".codebase-memory") | Out-Null
    Copy-Item $Candidate (Join-Path $Shadow ".codebase-memory\graph.db.zst")
    $PackagedGraph = $Candidate
  }
}

$GraphOut = Join-Path $Out "graph"
New-Item -ItemType Directory -Force -Path $GraphOut | Out-Null
Invoke-Cbm @("cli", "index_repository", "--repo-path", $Shadow, "--mode", "full", "--name", $CbmProject, "--persistence", "true") (Join-Path $GraphOut "index-result.json") | Out-Null
Invoke-Cbm @("cli", "get_graph_schema", "--project", $CbmProject) (Join-Path $GraphOut "schema.json") | Out-Null
Invoke-Cbm @("cli", "index_status", "--project", $CbmProject) (Join-Path $GraphOut "index-status.json") | Out-Null
Invoke-Cbm @("cli", "detect_changes", "--project", $CbmProject, "--since", $BaseSha, "--direction", "inbound", "--depth", "$Depth", "--limit", "$NodeBudget", "--format", "json") (Join-Path $Out "impact-review.json") | Out-Null

$Artifact = Join-Path $Shadow ".codebase-memory\graph.db.zst"
if (-not (Test-Path $Artifact -PathType Leaf)) { throw "Official graph artifact was not produced" }
Copy-Item $Artifact (Join-Path $GraphOut "graph.db.zst")
if (Test-Path (Join-Path $Shadow ".codebase-memory\artifact.json")) { Copy-Item (Join-Path $Shadow ".codebase-memory\artifact.json") $GraphOut }

$ChangedFiles = @()
$ChangedFiles += @(& git -C $Shadow diff --name-only "$BaseSha...HEAD")
$ChangedFiles += @(& git -C $Shadow diff --name-only HEAD)
$ChangedFiles += @(& git -C $Shadow ls-files --others --exclude-standard)
$ChangedFiles = @($ChangedFiles | Where-Object { $_ } | Sort-Object -Unique)
[IO.File]::WriteAllLines((Join-Path $Out "changed-files.txt"), $ChangedFiles, [Text.UTF8Encoding]::new($false))

$Packet = New-Object Text.StringBuilder
[void]$Packet.AppendLine("# AI verification packet")
[void]$Packet.AppendLine()
[void]$Packet.AppendLine("- Graph engine: codebase-memory-mcp 0.10.2")
[void]$Packet.AppendLine("- Project: ``$CbmProject``")
[void]$Packet.AppendLine("- Effective depth: $Depth (hard maximum 4)")
[void]$Packet.AppendLine("- Per-trace row budget: $TraceLimit")
[void]$Packet.AppendLine("- Global unique-node budget: $NodeBudget")
[void]$Packet.AppendLine("- Packaged graph reused: $(if ($PackagedGraph) {$PackagedGraph} else {'no'})")
[void]$Packet.AppendLine("`n## Changed-file symbol candidates")
foreach ($File in $ChangedFiles) {
  [void]$Packet.AppendLine("`n### ``$File`` `n`n``````text")
  $Search = Invoke-Cbm @("cli", "search_graph", "--project", $CbmProject, "--file-pattern", $File, "--limit", "$TraceLimit", "--format", "tree") ""
  [void]$Packet.AppendLine(($Search -join [Environment]::NewLine))
  [void]$Packet.AppendLine("```````n`nCoverage:`n`n``````text")
  $Coverage = Invoke-Cbm @("cli", "check_index_coverage", "--project", $CbmProject, "--paths", $File) ""
  [void]$Packet.AppendLine(($Coverage -join [Environment]::NewLine))
  [void]$Packet.AppendLine("``````")
}
[void]$Packet.AppendLine("`n## Required AI action`n")
[void]$Packet.AppendLine("For each prioritized changed symbol, call ``trace_path`` first at depth 1 with ``include_evidence=true``; expand one level at a time only while within the recorded budgets. Verify every retained edge against source and add missing dynamic or C/C++-Lua binding edges.")
[IO.File]::WriteAllText((Join-Path $Out "verification-packet.md"), $Packet.ToString(), [Text.UTF8Encoding]::new($false))

[ordered]@{
  schemaVersion=2
  engine=[ordered]@{name="codebase-memory-mcp"; version="0.10.2"; license="MIT"}
  sourceRoot=$RepoRoot; analysisRoot=$Shadow; project=$CbmProject; base=$BaseSha; head=$HeadSha
  requestedDepth=$Depth; effectiveDepth=$Depth; hardDepthLimit=4
  perTraceRowBudget=$TraceLimit; globalUniqueNodeBudget=$NodeBudget
  graphArtifact="graph/graph.db.zst"; targetRepositoryModified=$false
} | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 (Join-Path $Out "analysis-metadata.json")

@(
  "# Deterministic pre-review summary", "",
  "- Engine: codebase-memory-mcp 0.10.2 (MIT)",
  "- Source commit: ``$HeadSha``",
  "- Changed files: $($ChangedFiles.Count)",
  "- Traversal: depth $Depth, per trace $TraceLimit rows, global $NodeBudget unique nodes",
  "- AI source verification: required"
) | Set-Content -Encoding UTF8 (Join-Path $Out "summary.md")

Write-Host "OK: codebase-memory-mcp review artifacts written to $Out"
