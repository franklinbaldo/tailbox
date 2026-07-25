[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Version,
    [string]$TailBox,
    [string]$Engine,
    [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot

if (-not $TailBox) {
    $TailBox = Join-Path $repositoryRoot "target\release\tailbox.exe"
}
if (-not $Engine) {
    $Engine = Join-Path $repositoryRoot "target\release\tailbox-engine.exe"
}
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $repositoryRoot "dist"
}

foreach ($path in @($TailBox, $Engine)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required release input is missing: $path"
    }
}

$packagePath = Join-Path $OutputDirectory "package"
$archivePath = Join-Path $OutputDirectory "tailbox-windows-x64.zip"
$checksumPath = "$archivePath.sha256"

if (Test-Path -LiteralPath $packagePath) {
    Remove-Item -LiteralPath $packagePath -Recurse -Force
}
New-Item -ItemType Directory -Path $OutputDirectory, $packagePath -Force | Out-Null
Copy-Item -LiteralPath $TailBox -Destination (Join-Path $packagePath "tailbox.exe")
Copy-Item -LiteralPath $Engine -Destination (Join-Path $packagePath "tailbox-engine.exe")
Copy-Item -LiteralPath (Join-Path $repositoryRoot "LICENSE") -Destination (Join-Path $packagePath "LICENSE.txt")
$goModuleCache = (& go env GOMODCACHE).Trim()
$tailscaleLicense = Join-Path $goModuleCache "tailscale.com@v1.98.9\LICENSE"
if (-not (Test-Path -LiteralPath $tailscaleLicense -PathType Leaf)) {
    throw "Tailscale license not found in the Go module cache: $tailscaleLicense"
}
Copy-Item -LiteralPath $tailscaleLicense `
    -Destination (Join-Path $packagePath "LICENSE-Tailscale-BSD-3-Clause.txt")

@{
    version = $Version
    architecture = "windows-x64"
    backend = "tsnet"
    tailscaleVersion = "v1.98.9"
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $packagePath "manifest.json")

if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}
Compress-Archive -Path (Join-Path $packagePath "*") -DestinationPath $archivePath
$hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath $checksumPath -Value "$hash  tailbox-windows-x64.zip"

Get-Item -LiteralPath $archivePath, $checksumPath
