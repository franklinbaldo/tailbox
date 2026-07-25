# Architecture

TailBox is a host-side supervisor around a patched Tailscale daemon running as
a Linux ELF binary inside LiteBox.

```text
MCP client
   │ stdio
   ▼
TailBox Playwright wrapper ── starts ──► Playwright MCP
   │                                      │
   │ supervises                           │ SOCKS5
   ▼                                      ▼
LiteBox runner ── runs ──► tailscaled userspace networking
                                      │
                                      ▼
                                  tailnet
```

## Components

### TailBox supervisor

The planned Windows-native executable owns process lifetime, chooses unused
loopback ports, starts LiteBox, waits for readiness, and launches integrations.
It must keep stdout clean when acting as an MCP stdio server; status and login
messages belong on stderr or in a separate browser flow.

### LiteBox guest

LiteBox runs the patched Linux `tailscaled` without a full Linux VM. TailBox
uses Tailscale's userspace-networking mode, not a TUN device. The current guest
filesystem is memory-backed.

### Playwright integration

Playwright MCP supports `--proxy-server` and the
`PLAYWRIGHT_MCP_PROXY_SERVER` environment variable. The wrapper will point it
at TailBox's loopback SOCKS5 listener and transparently preserve MCP stdio.

### SSH integration

`tailbox connect HOST PORT` will relay stdin/stdout through SOCKS5. This can be
used as an OpenSSH `ProxyCommand`. `tailbox ssh` will provide a convenient
wrapper around the Windows OpenSSH client.

### Reverse access

Reverse forwarding is a separate opt-in feature. A future embedded,
unprivileged SSH endpoint may permit an authorized operator on a tailnet server
to reach the local Windows user session. It must never be enabled by login,
proxy, Playwright, or outbound SSH commands.

## Persistence

An out-of-box release needs an explicit host persistence bridge for Tailscale
state. Until that exists, restarting LiteBox requires login again. Auth keys and
state must never be stored in the repository or command-line arguments.

