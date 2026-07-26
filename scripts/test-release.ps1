[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern("^\d+\.\d+\.\d+$")]
    [string]$Version,
    [string]$Archive,
    [string]$Checksum
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if (-not $Archive) {
    $Archive = Join-Path $repositoryRoot "dist\tailbox-windows-x64.zip"
}
if (-not $Checksum) {
    $Checksum = "$Archive.sha256"
}

foreach ($path in @($Archive, $Checksum)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Release output is missing: $path"
    }
}

$checksumText = (Get-Content -LiteralPath $Checksum -Raw).Trim()
$checksumMatch = [regex]::Match(
    $checksumText,
    "^(?<hash>[0-9a-f]{64})  tailbox-windows-x64\.zip$"
)
if (-not $checksumMatch.Success) {
    throw "Checksum sidecar has an invalid format."
}
$actualHash = (Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -cne $checksumMatch.Groups["hash"].Value) {
    throw "Release archive does not match its SHA-256 sidecar."
}

$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    "tailbox-release-test-" + [guid]::NewGuid().ToString("N")
)
try {
    Expand-Archive -LiteralPath $Archive -DestinationPath $temporaryRoot
    $expectedFiles = @(
        "LICENSE-Tailscale-BSD-3-Clause.txt"
        "LICENSE.txt"
        "manifest.json"
        "tailbox-engine.exe"
        "tailbox.exe"
    )
    $actualFiles = @(
        Get-ChildItem -LiteralPath $temporaryRoot -File |
            Select-Object -ExpandProperty Name
    )
    $missingFiles = @($expectedFiles | Where-Object { $_ -cnotin $actualFiles })
    $unexpectedFiles = @($actualFiles | Where-Object { $_ -cnotin $expectedFiles })
    if (
        $actualFiles.Count -ne $expectedFiles.Count -or
        $missingFiles.Count -ne 0 -or
        $unexpectedFiles.Count -ne 0
    ) {
        throw "Unexpected package contents: $($actualFiles -join ', ')."
    }

    $manifest = Get-Content -LiteralPath (
        Join-Path $temporaryRoot "manifest.json"
    ) -Raw | ConvertFrom-Json
    if (
        $manifest.version -cne $Version -or
        $manifest.architecture -cne "windows-x64" -or
        $manifest.backend -cne "tsnet" -or
        $manifest.tailscaleVersion -cne "v1.98.9"
    ) {
        throw "Release manifest metadata is incorrect."
    }

    $reportedVersion = & (Join-Path $temporaryRoot "tailbox.exe") --version
    if ($LASTEXITCODE -ne 0 -or $reportedVersion -cne "tailbox $Version") {
        throw "Packaged tailbox.exe reported an unexpected version: $reportedVersion"
    }
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}

Write-Output "Release package and checksum verified for TailBox $Version."


