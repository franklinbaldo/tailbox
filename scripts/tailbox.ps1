[CmdletBinding()]
param(
    [ValidateRange(1, 65535)]
    [int]$ProxyPort = 1055
)

$ErrorActionPreference = "Stop"
$packageRoot = $PSScriptRoot
$runner = Join-Path $packageRoot "tailbox-runner.exe"
$image = Join-Path $packageRoot "tailscale-litebox.tar"

if (-not (Test-Path -LiteralPath $runner -PathType Leaf)) {
    throw "TailBox runner is missing: $runner"
}
if (-not (Test-Path -LiteralPath $image -PathType Leaf)) {
    throw "TailBox image is missing: $image"
}

Write-Output "TailBox proxy: socks5://127.0.0.1:$ProxyPort"
Write-Output "TailBox HTTP proxy: http://127.0.0.1:$ProxyPort"
Write-Output "Press Ctrl+C to stop it."

& $runner `
    --env TS_LITEBOX=1 `
    --env TS_LITEBOX_LOGIN=1 `
    --env GOGC=off `
    --forward-tcp "127.0.0.1:${ProxyPort}=10.0.0.2:${ProxyPort}" `
    --initial-files $image `
    /usr/local/bin/tailscaled `
    --tun=userspace-networking `
    --state=/tmp/tailscaled.state `
    --socket=/tmp/tailscaled.sock `
    "--socks5-server=127.0.0.1:$ProxyPort" `
    "--outbound-http-proxy-listen=127.0.0.1:$ProxyPort" `
    --no-logs-no-support

exit $LASTEXITCODE


