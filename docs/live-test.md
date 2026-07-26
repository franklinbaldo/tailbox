# Live test record

## Native tsnet backend — 2026-07-25

The native Windows x64 build was started as an ordinary user with no service,
driver, TUN adapter, or route change. The first run:

1. created state under `%LOCALAPPDATA%\TailBox\state`;
2. reached `NeedsLogin` and printed an interactive Tailscale authorization URL;
3. completed tailnet authentication without Windows elevation;
4. exposed SOCKS5 on `127.0.0.1:1055`;
5. exposed HTTP/HTTPS CONNECT on `127.0.0.1:1056`;
6. carried HTTPS requests through both proxy protocols.

The persisted native identity reported 19 tailnet peers, with one peer online
during the test. A SOCKS5 connection to that peer's TCP port 22 returned the
`SSH-2.0-Tailscale` protocol banner. The test did not authenticate to SSH or
execute a remote command. Peer names and addresses were not recorded.

After both processes were stopped, the second run loaded the persisted state,
reported `Running` without another login, reopened both proxies, and carried
another HTTPS request.

An initial supervisor build allowed the child engine to survive when the
supervisor was forcibly terminated. The Rust CLI was corrected to assign the
engine to a Windows Job Object with `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`.
A repeat test forcibly terminated only the supervisor and verified that the
engine exited and both loopback listeners closed.

The authorization URL, user identity, node addresses, and observed public IP
were intentionally not recorded.

Still untested on the native backend:

- Playwright MCP;
- authenticated SSH and command execution;
- a private HTTP endpoint (none was online on the tested common ports);
- a clean standard-user Windows installation.

## LiteBox backend — 2026-07-25

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
