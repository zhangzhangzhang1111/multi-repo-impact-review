param([Parameter(Mandatory = $true)][string]$Target)

$ErrorActionPreference = "Stop"
$Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
& (Join-Path $PSScriptRoot "verify-offline.ps1")
New-Item -ItemType Directory -Force -Path $Target | Out-Null
$Destination = Join-Path $Target "multi-repo-impact-review"
if (Test-Path $Destination) { throw "Target already exists: $Destination" }
Copy-Item -Recurse $Root $Destination
Write-Host "OK: installed offline plugin at $Destination"
