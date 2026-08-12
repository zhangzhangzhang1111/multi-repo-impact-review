$ErrorActionPreference = "Stop"
$Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$RuntimeInfo = [Runtime.InteropServices.RuntimeInformation]
$Os = if ($RuntimeInfo::IsOSPlatform([Runtime.InteropServices.OSPlatform]::Windows)) { "windows" } elseif ($RuntimeInfo::IsOSPlatform([Runtime.InteropServices.OSPlatform]::OSX)) { "darwin" } else { "linux" }
$ArchName = $RuntimeInfo::OSArchitecture.ToString().ToLowerInvariant()
$Arch = if ($ArchName -eq "x64") { "amd64" } elseif ($ArchName -eq "arm64") { "arm64" } else { throw "Unsupported architecture: $ArchName" }
$Executable = if ($Os -eq "windows") { "codebase-memory-mcp.exe" } else { "codebase-memory-mcp" }
$Binary = Join-Path $Root ("runtime\$Os-$Arch\$Executable")
if (-not (Test-Path $Binary -PathType Leaf)) { throw "Package does not contain runtime $Os-$Arch" }
& $Binary @args
exit $LASTEXITCODE
