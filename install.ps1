[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$repository = "franklinbaldo/tailbox"
$assetName = "tailbox-windows-x64.zip"
$installRoot = Join-Path $env:LOCALAPPDATA "TailBox"
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("tailbox-" + [guid]::NewGuid().ToString("N"))
$archivePath = Join-Path $temporaryRoot $assetName
$checksumPath = "$archivePath.sha256"
$stagingPath = Join-Path $temporaryRoot "package"

try {
    New-Item -ItemType Directory -Path $temporaryRoot, $stagingPath -Force | Out-Null

    Write-Output "Resolving the newest published TailBox release..."
    $releases = @(
        Invoke-RestMethod `
            -Uri "https://api.github.com/repos/$repository/releases?per_page=1" `
            -Headers @{ "User-Agent" = "TailBox-Installer" }
    )
    if ($releases.Count -eq 0) {
        throw "TailBox has no published release."
    }
    $release = $releases[0]
    $releaseVersion = [string]$release.tag_name
    if ($releaseVersion -notmatch "^v\d+\.\d+\.\d+$") {
        throw "The newest TailBox release has an invalid tag."
    }
    $releaseVersion = $releaseVersion.TrimStart("v")

    $archiveAsset = @($release.assets | Where-Object { $_.name -ceq $assetName })
    $checksumAsset = @(
        $release.assets | Where-Object { $_.name -ceq "$assetName.sha256" }
    )
    if ($archiveAsset.Count -ne 1 -or $checksumAsset.Count -ne 1) {
        throw "The newest TailBox release is missing required Windows assets."
    }
    foreach ($asset in @($archiveAsset[0], $checksumAsset[0])) {
        $assetUri = [uri]$asset.browser_download_url
        if ($assetUri.Scheme -cne "https" -or $assetUri.Host -cne "github.com") {
            throw "GitHub returned an unexpected release asset URL."
        }
    }

    Write-Output "Downloading TailBox $releaseVersion..."
    Invoke-WebRequest $archiveAsset[0].browser_download_url -OutFile $archivePath
    Invoke-WebRequest $checksumAsset[0].browser_download_url -OutFile $checksumPath

    $checksumText = (Get-Content -LiteralPath $checksumPath -Raw).Trim()
    $checksumMatch = [regex]::Match(
        $checksumText,
        "^(?<hash>[0-9a-f]{64})  tailbox-windows-x64\.zip$"
    )
    if (-not $checksumMatch.Success) {
        throw "The release checksum is malformed."
    }
    $expectedHash = $checksumMatch.Groups["hash"].Value

    $actualHash = (
        Get-FileHash -LiteralPath $archivePath -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    if ($actualHash -cne $expectedHash) {
        throw "TailBox checksum mismatch. Nothing was installed."
    }

    Expand-Archive -LiteralPath $archivePath -DestinationPath $stagingPath
    $manifest = Get-Content -LiteralPath (Join-Path $stagingPath "manifest.json") -Raw |
        ConvertFrom-Json
    if (
        $manifest.version -cne $releaseVersion -or
        $manifest.architecture -cne "windows-x64" -or
        $manifest.backend -cne "tsnet"
    ) {
        throw "The TailBox package manifest does not match the selected release."
    }

    $versionPath = Join-Path $installRoot $manifest.version
    if (Test-Path -LiteralPath $versionPath) {
        Remove-Item -LiteralPath $versionPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
    Move-Item -LiteralPath $stagingPath -Destination $versionPath
    Set-Content -LiteralPath (Join-Path $installRoot "current.txt") -Value $manifest.version

    Write-Output "Verified and installed TailBox $($manifest.version)."
    Write-Output "Starting the local proxy. Follow the Tailscale login URL, then leave this window open."
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


