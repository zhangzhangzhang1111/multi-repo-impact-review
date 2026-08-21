$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Source = Join-Path $Root "skills/multi-repo-impact-review"
$Target = if ($args.Count -gt 0) { $args[0] } else { "" }

if ($Target -notin @("codex", "claude", "both")) {
  [Console]::Error.WriteLine("Usage: install-skill.ps1 codex|claude|both")
  exit 2
}

$CodexRoot = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }
$ClaudeRoot = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } elseif ($env:CLAUDE_HOME) { $env:CLAUDE_HOME } else { Join-Path $HOME ".claude" }
$Destinations = @{}
if ($Target -in @("codex", "both")) { $Destinations["Codex"] = Join-Path $CodexRoot "skills/multi-repo-impact-review" }
if ($Target -in @("claude", "both")) { $Destinations["Claude"] = Join-Path $ClaudeRoot "skills/multi-repo-impact-review" }

foreach ($Destination in $Destinations.Values) {
  if (Test-Path -LiteralPath $Destination) {
    [Console]::Error.WriteLine("# Skill 安装结论`n`n- **结论：失败**`n- **原因：目标目录已存在** ``$Destination``")
    exit 2
  }
}

foreach ($Entry in $Destinations.GetEnumerator()) {
  $Parent = Split-Path -Parent $Entry.Value
  New-Item -ItemType Directory -Force -Path $Parent | Out-Null
  Copy-Item -Recurse -LiteralPath $Source -Destination $Entry.Value
}

Write-Output "# Skill 安装结论"
Write-Output ""
Write-Output "- **结论：成功**"
foreach ($Entry in $Destinations.GetEnumerator() | Sort-Object Name) {
  Write-Output "- **$($Entry.Name)**：``$($Entry.Value)``"
}
Write-Output "- **知识图谱环境：未安装、未下载、未修改**"
