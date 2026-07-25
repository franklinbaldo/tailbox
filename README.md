# TailBox

**Give humans and AI agents access to private tailnet resources from an
unprivileged Windows account.**

TailBox is an experimental compatibility layer that runs Tailscale's userspace
networking inside [Microsoft LiteBox](https://github.com/microsoft/litebox).
It is intended for Windows computers where the user cannot install a VPN
driver, Windows service, or virtual network adapter.

The first target integration launches
[Playwright MCP](https://github.com/microsoft/playwright-mcp) through a local
TailBox SOCKS5 proxy. This lets an AI agent browse private web applications on
the user's tailnet. TailBox also aims to provide outbound SSH access and
explicit, tightly controlled reverse tunnels for human operators.

> [!WARNING]
> TailBox is an early experiment, not a security boundary or a system-wide VPN.
> The current prototype disables Go garbage collection due to an unresolved
> runtime crash, so it is suitable only for short experiments.

## Install and run on Windows

From an unprivileged PowerShell prompt:

```powershell
irm https://github.com/franklinbaldo/tailbox/releases/latest/download/install.ps1 | iex
```

The bootstrap downloads the Windows x64 release package, verifies its SHA-256
checksum, installs it under `%LOCALAPPDATA%\TailBox`, and starts a local
SOCKS5/HTTP proxy at `127.0.0.1:1055`. Follow the Tailscale authorization URL
shown in the terminal and leave the process running.

The one-line bootstrap itself is trusted through GitHub HTTPS. The downloaded
package is not extracted or executed until its published checksum matches.

## What TailBox aims to provide

```text
Agent → Playwright MCP ─┐
Human → SSH client ─────┼→ TailBox proxy → Tailscale → private services
Other proxy-aware app ──┘
```

- Browser access for agents through Playwright MCP.
- Interactive SSH from Windows to a tailnet machine.
- A local SOCKS5/HTTP proxy for explicitly configured applications.
- Optional reverse SSH tunnels, disabled by default.
- No administrator privileges, kernel driver, Windows service, or full Linux
  virtual machine.

TailBox does **not** place every Windows application on the tailnet. Only
applications launched through TailBox or configured to use its proxy receive
tailnet connectivity.

## Intended experience

The planned Playwright MCP configuration is:

```json
{
  "mcpServers": {
    "playwright-tailbox": {
      "command": "npx",
      "args": ["-y", "@tailbox/playwright"]
    }
  }
}
```

Planned human-facing commands:

```console
tailbox login
tailbox playwright
tailbox ssh user@my-server
tailbox proxy
tailbox reverse-shell user@my-server --authorized-key id_ed25519.pub
```

These commands describe the product direction; only the release bootstrap and
local proxy are implemented today.

## Current prototype

The prototype currently:

- Builds a statically linked `tailscaled` based on Tailscale `v1.98.9`.
- Rewrites its Linux syscall sites for LiteBox.
- Runs it in userspace-networking mode.
- Requests interactive Tailscale login from the daemon process.
- Configures loopback SOCKS5 and HTTP proxy listeners.

The working development checkout uses:

- LiteBox commit `6a03ec80f065d2a66b937bde3d6f0708d282ca27`
- Tailscale tag `v1.98.9`, commit
  `6c167d40fa37aeb51afa7ff336730670ea4762bf`
- Go `1.26.5`

The compatibility changes are stored in [`patches/`](patches/). Generated
images, SDKs, executables, logs, credentials, and runtime state are deliberately
excluded from Git.

Developers with the existing sibling checkouts and prototype image can run:

```powershell
.\scripts\run-prototype.ps1
```

See [the architecture](docs/architecture.md), [security model](docs/security.md),
[live test record](docs/live-test.md), and [roadmap](docs/roadmap.md) before
using the prototype.

## Status

TailBox has completed its first live Windows proof: a patched `tailscaled`
authenticated with the Tailscale control plane, reached `Running`, loaded ten
tailnet peers, connected to a DERP relay, exposed a host-loopback SOCKS5 proxy,
and carried an HTTPS request from Windows through that proxy.

The largest unresolved requirements are:

1. Persisting Tailscale authentication outside LiteBox's memory-backed
   filesystem.
2. Fixing Go stack unwinding during garbage collection; the short proof used
   `GOGC=off` and is not suitable for an indefinitely running process.
3. Testing Playwright MCP and a private tailnet HTTP endpoint through the
   verified proxy.

## License

TailBox's original integration code is licensed under the MIT License. LiteBox
and Tailscale remain governed by their respective upstream licenses. A release
process must preserve all required third-party notices.
