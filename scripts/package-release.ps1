[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern("^\d+\.\d+\.\d+$")]
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
$engineDirectory = Join-Path $repositoryRoot "engine"
Push-Location $engineDirectory
try {
    $tailscaleModule = (& go list -m -f "{{.Version}}|{{.Dir}}" tailscale.com).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to resolve the Tailscale Go module."
    }
}
finally {
    Pop-Location
}
$tailscaleModuleParts = $tailscaleModule.Split("|", 2)
if (
    $tailscaleModuleParts.Count -ne 2 -or
    $tailscaleModuleParts[0] -notmatch "^v\d+\.\d+\.\d+$"
) {
    throw "The resolved Tailscale Go module metadata is invalid."
}
$tailscaleVersion = $tailscaleModuleParts[0]
$tailscaleLicense = Join-Path $tailscaleModuleParts[1] "LICENSE"
if (-not (Test-Path -LiteralPath $tailscaleLicense -PathType Leaf)) {
    throw "Tailscale license not found in the resolved module: $tailscaleLicense"
}
Copy-Item -LiteralPath $tailscaleLicense `
    -Destination (Join-Path $packagePath "LICENSE-Tailscale-BSD-3-Clause.txt")

@{
    version          = $Version
    architecture     = "windows-x64"
    backend          = "tsnet"
    tailscaleVersion = $tailscaleVersion
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $packagePath "manifest.json")

if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}
if (Test-Path -LiteralPath $checksumPath) {
    Remove-Item -LiteralPath $checksumPath -Force
}
Compress-Archive -Path (Join-Path $packagePath "*") -DestinationPath $archivePath
$hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath $checksumPath -Value "$hash  tailbox-windows-x64.zip"

Get-Item -LiteralPath $archivePath, $checksumPath


