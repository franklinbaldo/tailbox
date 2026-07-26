[CmdletBinding()]
param(
    [string]$Runner,
    [string]$Image,
    [ValidateRange(1, 65535)]
    [int]$ProxyPort = 1055
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

if (-not (Test-Path -LiteralPath $Runner -PathType Leaf)) {
    throw "LiteBox runner not found: $Runner"
}
if (-not (Test-Path -LiteralPath $Image -PathType Leaf)) {
    throw "Prototype image not found: $Image"
}

$env:TS_LITEBOX = "1"
$env:TS_LITEBOX_LOGIN = "1"

Write-Output "Starting experimental TailBox proxy on 127.0.0.1:$ProxyPort"
Write-Output "This contacts Tailscale and will request browser authorization."
Write-Output "Press Ctrl+C to stop it."

& $Runner `
    --env TS_LITEBOX=1 `
    --env TS_LITEBOX_LOGIN=1 `
    --env GOGC=off `
    --forward-tcp "127.0.0.1:${ProxyPort}=10.0.0.2:${ProxyPort}" `
    --initial-files $Image `
    /usr/local/bin/tailscaled `
    --tun=userspace-networking `
    --state=/tmp/tailscaled.state `
    --socket=/tmp/tailscaled.sock `
    "--socks5-server=127.0.0.1:$ProxyPort" `
    "--outbound-http-proxy-listen=127.0.0.1:$ProxyPort" `
    --no-logs-no-support

exit $LASTEXITCODE
