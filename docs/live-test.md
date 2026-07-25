# Live test record

Date: 2026-07-25

Platform: Windows x64, standard user process

LiteBox: `6a03ec80f065d2a66b937bde3d6f0708d282ca27`

Tailscale: `v1.98.9`

## Passed

- BusyBox DNS lookup from the LiteBox guest.
- Guest TCP connection to a public IPv4 endpoint.
- Tailscale control-plane HTTPS connection.
- Interactive browser authorization.
- Tailscale state transition from `NeedsLogin` to `Running`.
- Netmap containing ten peers.
- UDP connectivity and DERP relay connection.
- Host listener on `127.0.0.1:1055`.
- Host HTTPS request through `socks5h://127.0.0.1:1055`.
- Host HTTPS request through `http://127.0.0.1:1055`.

## Known limitations observed

- The guest filesystem is memory-backed, so authentication is lost at exit.
- Go garbage collection eventually failed while unwinding a guest stack with
  `fatal error: traceback did not unwind completely`.
- The successful short run therefore used `GOGC=off`. Memory can grow without
  bound in this mode, so it is not acceptable for unattended or long-lived use.
- IPv6 guest sockets remain unsupported.
- A private tailnet HTTP endpoint and Playwright MCP have not yet been exercised.

## Reproduction check

With the prototype running and authorized:

```powershell
curl.exe --proxy socks5h://127.0.0.1:1055 https://api.ipify.org
```

The command completed successfully through TailBox. The returned public address
is intentionally not recorded.
