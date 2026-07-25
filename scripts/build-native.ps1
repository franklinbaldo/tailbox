[CmdletBinding()]
param(
    [string]$RustTarget
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$releaseDirectory = Join-Path $repositoryRoot "target\release"
New-Item -ItemType Directory -Path $releaseDirectory -Force | Out-Null

Push-Location (Join-Path $repositoryRoot "engine")
try {
    go test ./...
    if ($LASTEXITCODE -ne 0) {
        throw "Go tests failed with exit code $LASTEXITCODE."
    }
    go build -trimpath -ldflags "-s -w" `
        -o (Join-Path $releaseDirectory "tailbox-engine.exe") .
    if ($LASTEXITCODE -ne 0) {
        throw "Go build failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

Push-Location $repositoryRoot
try {
    $cargoArguments = @()
    if ($RustTarget) {
        $cargoArguments += @("--target", $RustTarget)
    }
    cargo test --release @cargoArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Rust tests failed with exit code $LASTEXITCODE."
    }
    cargo build --release @cargoArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Rust build failed with exit code $LASTEXITCODE."
    }
    if ($RustTarget) {
        Copy-Item -LiteralPath `
            (Join-Path $repositoryRoot "target\$RustTarget\release\tailbox.exe") `
            -Destination (Join-Path $releaseDirectory "tailbox.exe")
    }
}
finally {
    Pop-Location
}

Get-Item `
    (Join-Path $releaseDirectory "tailbox.exe"), `
    (Join-Path $releaseDirectory "tailbox-engine.exe")
