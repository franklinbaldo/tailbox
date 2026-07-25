# Roadmap

## Phase 0: compatibility proof

- [x] Start a patched `tailscaled` ELF inside LiteBox.
- [x] Initialize Tailscale's userspace WireGuard engine.
- [x] Reach Tailscale's `NeedsLogin` state.
- [x] Isolate the current failure with guest DNS and direct-IP HTTP tests.
- [x] Implement an experimental Windows-userland network bridge in LiteBox.
- [x] Configure a host-visible SOCKS5 proxy listener.
- [x] Complete browser login with unrestricted outbound networking.
- [x] Carry a host HTTPS request through the SOCKS5 proxy.
- [ ] Reach a tailnet HTTP service from a host browser.
- [ ] Fix Go GC stack unwinding and remove `GOGC=off`.

## Phase 1: repeatable developer build

- [ ] Fetch and verify pinned LiteBox and Tailscale sources.
- [ ] Apply compatibility patches without manual edits.
- [ ] Build the runner and rewritten Tailscale image.
- [ ] Add smoke tests and artifact checksums.

## Phase 2: unprivileged Windows product

- [ ] Persist encrypted Tailscale state in the user's profile.
- [ ] Select dynamic loopback ports and expose readiness.
- [ ] Provide `tailbox login`, `logout`, `status`, and `proxy`.
- [ ] Test on clean Windows 10/11 x64 standard-user accounts.
- [ ] Produce signed, checksummed releases.

## Phase 3: integrations

- [ ] Publish a Playwright MCP wrapper.
- [ ] Implement `tailbox connect` as an OpenSSH `ProxyCommand`.
- [ ] Implement `tailbox ssh`.
- [ ] Design and threat-model opt-in reverse tunnels.
- [ ] Implement restricted reverse execution before considering a full shell.
