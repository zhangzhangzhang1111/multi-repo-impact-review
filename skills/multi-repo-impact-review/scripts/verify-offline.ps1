$ErrorActionPreference = "Stop"
$SkillRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$RuntimeInfo = [Runtime.InteropServices.RuntimeInformation]
$Os = if ($RuntimeInfo::IsOSPlatform([Runtime.InteropServices.OSPlatform]::Windows)) { "windows" } elseif ($RuntimeInfo::IsOSPlatform([Runtime.InteropServices.OSPlatform]::OSX)) { "darwin" } else { "linux" }
$ArchName = $RuntimeInfo::OSArchitecture.ToString().ToLowerInvariant()
$Arch = if ($ArchName -eq "x64") { "amd64" } elseif ($ArchName -eq "arm64") { "arm64" } else { throw "Unsupported architecture: $ArchName" }
$Executable = if ($Os -eq "windows") { "codebase-memory-mcp.exe" } else { "codebase-memory-mcp" }
$Engine = if ($env:MULTI_REPO_IMPACT_CBM) { $env:MULTI_REPO_IMPACT_CBM } else { Join-Path $SkillRoot "runtime\$Os-$Arch\$Executable" }

foreach ($Required in @($Engine, (Join-Path $SkillRoot "SKILL.md"), (Join-Path $SkillRoot "agents\openai.yaml"), (Join-Path $SkillRoot "project-packs\project-map.tsv"), (Join-Path $SkillRoot "vendor\codebase-memory-mcp\LICENSE"), (Join-Path $SkillRoot "vendor\codebase-memory-mcp\THIRD_PARTY_NOTICES.md"))) {
  if (-not (Test-Path $Required -PathType Leaf)) { throw "Missing Skill file: $Required" }
}
foreach ($Forbidden in @((Join-Path $SkillRoot ".mcp.json"), (Join-Path $SkillRoot ".codex-plugin"), (Join-Path $SkillRoot ".claude-plugin"))) {
  if (Test-Path $Forbidden) { throw "Plugin-only file must not be present: $Forbidden" }
}

$Checksums = Join-Path $SkillRoot "checksums\SHA256SUMS"
if (Test-Path $Checksums -PathType Leaf) {
  Get-Content $Checksums | ForEach-Object {
    if ($_ -match '^([0-9a-f]{64})\s+\.\/(.+)$') {
      $Expected = $Matches[1]
      $File = Join-Path $SkillRoot $Matches[2].Replace('/', [IO.Path]::DirectorySeparatorChar)
      if (-not (Test-Path $File -PathType Leaf)) { throw "Missing package file: $File" }
      if ((Get-FileHash -Algorithm SHA256 $File).Hash.ToLowerInvariant() -ne $Expected) { throw "Checksum mismatch: $File" }
    }
  }
}

$Version = (& $Engine --version 2>$null) -join "`n"
if ($LASTEXITCODE -ne 0 -or $Version -notmatch 'codebase-memory-mcp 0\.10\.2') { throw "Unexpected graph engine version: $Version" }
& $Engine cli index_repository --help | Out-Null
& $Engine cli trace_path --help | Out-Null
Write-Host "OK: pure Skill and official runtime verified for $Os-$Arch"
