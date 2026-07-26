# Roadmap

## Phase 0: LiteBox compatibility proof

- [x] Run a patched Linux `tailscaled` inside LiteBox.
- [x] Add Windows userspace TCP/UDP transport.
- [x] Authenticate and reach the Tailscale `Running` state.
- [x] Carry host HTTPS through SOCKS5 and HTTP proxies.
- [x] Record the Go unwinding and persistence limitations.

## Phase 1: native Windows backend

- [x] Verify that upstream `libtailscale` does not currently build on Windows.
- [x] Build a native `tsnet` engine without administrator privileges.
- [x] Build a small Rust CLI supervisor.
- [x] Persist state under `%LOCALAPPDATA%\TailBox`.
- [x] Add loopback SOCKS5 and HTTP proxy listeners.
- [x] Reduce the compiled payload to approximately 22.5 MB.
- [x] Complete interactive native login and public proxy traffic tests.
- [x] Restart without login and reuse persisted identity.
- [x] Ensure the Windows Job Object closes the engine with its supervisor.
- [ ] Reach a private tailnet service through the native proxies.
- [ ] Test on clean Windows 10/11 x64 standard-user accounts.

## Phase 2: release

- [x] Add SHA-256-verified `irm ... | iex` installation.
- [x] Add a Windows GitHub Actions release build.
- [ ] Add Authenticode signing.
- [ ] Publish the first GitHub release.
- [ ] Add `uvx tailbox` as a wrapper around verified release assets.
- [ ] Evaluate a developer-only Cargo installation workflow.

## Phase 3: integrations

- [ ] Validate Playwright MCP against a private tailnet site.
- [ ] Implement `tailbox connect` as an OpenSSH `ProxyCommand`.
- [ ] Implement `tailbox ssh`.
- [ ] Threat-model opt-in reverse tunnels.
- [ ] Implement restricted reverse execution before a full shell.
