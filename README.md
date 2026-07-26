# TailBox

**Application-scoped tailnet access for humans and AI agents on Windows
without administrator privileges.**

TailBox runs an embedded Tailscale node in userspace and exposes local SOCKS5
and HTTP proxies. It does not install a VPN adapter, Windows service, driver,
or system-wide route. Only applications explicitly configured for the proxy
use the tailnet.

> [!WARNING]
> TailBox is an early experiment. The native backend has completed interactive
> login, public proxy traffic, private Tailscale SSH transport, persistence,
> and lifecycle tests on Windows x64, but it has not yet completed a
> clean-machine acceptance test or independent security review.

## Install and run

From an unprivileged PowerShell prompt:

```powershell
irm https://raw.githubusercontent.com/franklinbaldo/tailbox/main/install.ps1 | iex
```

The bootstrap downloads the Windows x64 package, verifies its SHA-256 checksum,
installs it under `%LOCALAPPDATA%\TailBox`, and starts TailBox. On first use,
open the Tailscale authorization URL printed in the terminal.

During the prerelease phase, the bootstrap resolves the newest published
GitHub release through the GitHub API because `/releases/latest` excludes
prereleases. It verifies that the archive, checksum, release tag, and package
manifest agree before running either executable.

TailBox then listens only on Windows loopback:

```text
SOCKS5  socks5://127.0.0.1:1055
HTTP    http://127.0.0.1:1056
```

The bootstrap itself is trusted through GitHub HTTPS. The downloaded package
is not extracted or executed until its published checksum matches.

## Agents and Playwright MCP

Start TailBox and leave it running:

```powershell
tailbox proxy
```

Then launch a proxy-aware agent tool, for example:

```powershell
npx @playwright/mcp@latest --proxy-server=socks5://127.0.0.1:1055
```

Playwright MCP integration remains to be validated against a private tailnet
site before it is considered supported.

## Architecture

```text
Playwright / browser / SSH client
              |
      SOCKS5 or HTTP proxy
              |
        tailbox.exe (Rust CLI)
              |
    tailbox-engine.exe (Go + tsnet)
              |
            tailnet
```

The small Rust executable owns the user-facing CLI and process lifecycle. The
Go engine embeds Tailscale's official
[`tsnet`](https://tailscale.com/docs/features/tsnet) implementation. State and
node identity persist under `%LOCALAPPDATA%\TailBox\state`.

The release contains two executables because the official `libtailscale` C API
currently uses POSIX file descriptors and does not compile on Windows. A pure
Rust Tailscale backend is also not suitable yet: `tailscale-rs` explicitly
describes itself as unaudited and insecure and does not currently support
Windows.

## Why LiteBox is no longer the default

The original proof ran a patched Linux `tailscaled` inside Microsoft LiteBox
and demonstrated real SOCKS5 and HTTP traffic through a tailnet from Windows.
That experiment remains in [`patches/`](patches/) and
[`scripts/run-prototype.ps1`](scripts/run-prototype.ps1).

LiteBox remains interesting as a future optional backend for running a
restricted Linux tool environment alongside Tailscale. It is not needed for
the primary proxy use case, and removing it from the default path eliminates
the Linux image, syscall patches, user-mode NAT bridge, non-persistent state,
and the observed Go stack-unwinding failure.

## Build

The build uses pinned Tailscale `v1.98.9`, Go 1.26, and stable Rust:

```powershell
.\scripts\build-native.ps1
.\scripts\package-release.ps1 -Version 0.1.0
```

Generated executables and release archives are excluded from Git. Official
upstream source is consumed as a dependency rather than vendored.

`cargo install tailbox` is intentionally unavailable because Cargo alone
cannot build the required Go engine. A future `uvx tailbox` package can wrap
the same signed/checksummed GitHub release without compiling locally.

See [architecture](docs/architecture.md), [security](docs/security.md),
[live test history](docs/live-test.md), and [roadmap](docs/roadmap.md).

## Release quality

Pull requests build and test both the Rust supervisor and Go engine on
GitHub-hosted Windows, run Rustfmt, Clippy, gofmt, go vet, and
PSScriptAnalyzer, then generate and inspect the complete release archive. Each
PR must increase the Cargo SemVer version and add one matching
`changelog/<version>.md`. Workflow dependencies are pinned to immutable commit
SHAs and monitored by Dependabot.

## License

TailBox's original code is MIT licensed. Tailscale and tsnet are BSD
3-Clause-licensed and remain governed by their upstream license.
