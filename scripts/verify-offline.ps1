$ErrorActionPreference = "Stop"
$Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$Checksums = Join-Path $Root "checksums\SHA256SUMS"
$RuntimeInfo = [Runtime.InteropServices.RuntimeInformation]
$Os = if ($RuntimeInfo::IsOSPlatform([Runtime.InteropServices.OSPlatform]::Windows)) { "windows" } elseif ($RuntimeInfo::IsOSPlatform([Runtime.InteropServices.OSPlatform]::OSX)) { "darwin" } else { "linux" }
$ArchName = $RuntimeInfo::OSArchitecture.ToString().ToLowerInvariant()
$Arch = if ($ArchName -eq "x64") { "amd64" } elseif ($ArchName -eq "arm64") { "arm64" } else { throw "Unsupported architecture: $ArchName" }
$Executable = if ($Os -eq "windows") { "codebase-memory-mcp.exe" } else { "codebase-memory-mcp" }
$Engine = Join-Path $Root ("runtime\$Os-$Arch\$Executable")

foreach ($Required in @($Engine, $Checksums, (Join-Path $Root ".codex-plugin\plugin.json"), (Join-Path $Root ".claude-plugin\plugin.json"), (Join-Path $Root ".mcp.json"), (Join-Path $Root "skills\multi-repo-impact-review\SKILL.md"), (Join-Path $Root "vendor\codebase-memory-mcp\LICENSE"), (Join-Path $Root "vendor\codebase-memory-mcp\THIRD_PARTY_NOTICES.md"))) {
  if (-not (Test-Path $Required -PathType Leaf)) { throw "Missing package file: $Required" }
}

Get-Content $Checksums | ForEach-Object {
  if ($_ -match '^([0-9a-f]{64})\s+\.\/(.+)$') {
    $Expected = $Matches[1]
    $Relative = $Matches[2].Replace('/', [IO.Path]::DirectorySeparatorChar)
    $File = Join-Path $Root $Relative
    if (-not (Test-Path $File -PathType Leaf)) { throw "Missing package file: $Relative" }
    $Actual = (Get-FileHash -Algorithm SHA256 $File).Hash.ToLowerInvariant()
    if ($Actual -ne $Expected) { throw "Checksum mismatch: $Relative" }
  }
}

$Version = (& $Engine --version) -join "`n"
if ($LASTEXITCODE -ne 0 -or $Version -notmatch 'codebase-memory-mcp 0\.10\.2') { throw "Unexpected graph engine version: $Version" }
& $Engine cli trace_path --help | Out-Null
if ($LASTEXITCODE -ne 0) { throw "codebase-memory-mcp CLI self-check failed" }
Write-Host "OK: official codebase-memory-mcp offline package verified for $Os-$Arch"
