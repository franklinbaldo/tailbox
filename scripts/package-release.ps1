[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Version,
    [string]$Runner,
    [string]$Image,
    [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $repositoryRoot

if (-not $Runner) {
    $Runner = Join-Path $workspaceRoot "litebox\target\x86_64-pc-windows-gnu\release\litebox_runner_linux_on_windows_userland.exe"
}
if (-not $Image) {
    $Image = Join-Path $workspaceRoot "litebox-experiment\tailscale-v1.98.9-experimental-litebox.tar"
}
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $repositoryRoot "dist"
}

foreach ($path in @($Runner, $Image)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required release input is missing: $path"
    }
}

$packagePath = Join-Path $OutputDirectory "package"
$archivePath = Join-Path $OutputDirectory "tailbox-windows-x64.zip"
$checksumPath = "$archivePath.sha256"

New-Item -ItemType Directory -Path $OutputDirectory, $packagePath -Force | Out-Null
Copy-Item -LiteralPath $Runner -Destination (Join-Path $packagePath "tailbox-runner.exe")
Copy-Item -LiteralPath $Image -Destination (Join-Path $packagePath "tailscale-litebox.tar")
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "tailbox.ps1") -Destination $packagePath

@{
    version = $Version
    architecture = "windows-x64"
    liteboxCommit = "6a03ec80f065d2a66b937bde3d6f0708d282ca27"
    tailscaleVersion = "v1.98.9"
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $packagePath "manifest.json")

if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}
Compress-Archive -Path (Join-Path $packagePath "*") -DestinationPath $archivePath
$hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath $checksumPath -Value "$hash  tailbox-windows-x64.zip"

Get-Item -LiteralPath $archivePath, $checksumPath
