# Architecture

TailBox's default backend is native Windows userspace networking.

```text
MCP / browser / OpenSSH
          |
  SOCKS5 :1055 or HTTP :1056
          |
  tailbox.exe (Rust supervisor)
          |
  tailbox-engine.exe (Go + official tsnet)
          |
        tailnet
```

## Rust supervisor

`tailbox.exe` owns the stable user-facing command line and starts the engine
from the same release directory. Keeping this layer small lets future commands
such as `ssh`, `playwright`, and restricted reverse tunnels share one Windows
interface without reimplementing the Tailscale protocol.

## Native engine

`tailbox-engine.exe` embeds the official `tailscale.com/tsnet` package. It
creates no TUN adapter and changes no Windows routes. It persists node identity
under `%LOCALAPPDATA%\TailBox\state`, waits for interactive login on first use,
and dials requested destinations through the tailnet.

The engine serves:

- an unauthenticated SOCKS5 proxy on `127.0.0.1:1055`;
- an unauthenticated HTTP/HTTPS CONNECT proxy on `127.0.0.1:1056`.

Both listeners are loopback-only. Remote exposure is not configurable.

## Why two executables

The official `libtailscale` C library currently models connections as POSIX
file descriptors and uses Unix socket pairs. A direct build on Windows x64
fails at `sys/socket.h`. TailBox therefore uses `tsnet` directly in a small Go
engine instead of maintaining a private Windows FFI fork.

The Rust `tailscale-rs` implementation is not currently a viable replacement:
upstream labels it unaudited and insecure, and Windows support is not present.

## LiteBox backend

The earlier LiteBox proof remains reviewable in `patches/` and
`scripts/run-prototype.ps1`. It demonstrated that the Linux `tailscaled` could
authenticate and proxy traffic through a patched LiteBox network bridge.

LiteBox may later return as an optional Linux tool sandbox. Its Windows
userland isolation is not a documented or independently verified security
boundary, so TailBox must not represent it as one.

## Planned integrations

- Playwright MCP receives `--proxy-server=socks5://127.0.0.1:1055`.
- OpenSSH receives a TailBox-backed `ProxyCommand`.
- Reverse access remains a separate, explicit, off-by-default feature.
