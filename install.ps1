[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$repository = "franklinbaldo/tailbox"
$assetName = "tailbox-windows-x64.zip"
$releaseBase = "https://github.com/$repository/releases/latest/download"
$installRoot = Join-Path $env:LOCALAPPDATA "TailBox"
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("tailbox-" + [guid]::NewGuid().ToString("N"))
$archivePath = Join-Path $temporaryRoot $assetName
$checksumPath = "$archivePath.sha256"
$stagingPath = Join-Path $temporaryRoot "package"

try {
    New-Item -ItemType Directory -Path $temporaryRoot, $stagingPath -Force | Out-Null

    Write-Host "Downloading TailBox..."
    Invoke-WebRequest "$releaseBase/$assetName" -OutFile $archivePath
    Invoke-WebRequest "$releaseBase/$assetName.sha256" -OutFile $checksumPath

    $expectedHash = ((Get-Content -LiteralPath $checksumPath -Raw).Trim() -split "\s+")[0]
    if ($expectedHash -notmatch "^[0-9a-fA-F]{64}$") {
        throw "The release checksum is malformed."
    }

    $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedHash) {
        throw "TailBox checksum mismatch. Nothing was installed."
    }

    Expand-Archive -LiteralPath $archivePath -DestinationPath $stagingPath
    $manifest = Get-Content -LiteralPath (Join-Path $stagingPath "manifest.json") -Raw |
        ConvertFrom-Json
    if (-not $manifest.version) {
        throw "The TailBox package manifest has no version."
    }

    $versionPath = Join-Path $installRoot $manifest.version
    if (Test-Path -LiteralPath $versionPath) {
        Remove-Item -LiteralPath $versionPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
    Move-Item -LiteralPath $stagingPath -Destination $versionPath
    Set-Content -LiteralPath (Join-Path $installRoot "current.txt") -Value $manifest.version

    Write-Host "Verified and installed TailBox $($manifest.version)."
    Write-Host "Starting the local proxy. Follow the Tailscale login URL, then leave this window open."
    & (Join-Path $versionPath "tailbox.exe")
    if ($LASTEXITCODE -ne 0) {
        throw "TailBox stopped with exit code $LASTEXITCODE."
    }
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
