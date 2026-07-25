# Security model

TailBox provides connectivity and is not itself a security boundary.

## Default boundary

- Proxy listeners bind to Windows loopback only.
- TailBox changes no system routes or proxy settings.
- TailBox runs with the current user's privileges.
- Reverse tunnels and command execution are disabled by default.
- Authentication state and keys are excluded from source control.
- MCP protocol data uses stdout; diagnostic information uses stderr.
- Persistent Tailscale identity is stored in the current user's local profile.
- Local proxy clients are not authenticated; any process able to connect to
  loopback on the same Windows host may attempt to use the listeners.

## Playwright and agents

Content reached through a tailnet can still contain prompt injection or hostile
scripts. Playwright MCP grants an agent browser automation capability; TailBox
does not make that capability safe. Users should constrain allowed origins and
grant the agent access only to resources it needs.

## Reverse shell

Reverse access is remote command execution under the Windows account running
TailBox. A release must require an explicit command and:

- key-only authentication;
- an explicit authorized-key allowlist;
- remote binding to `127.0.0.1` by default;
- conspicuous session status;
- an audit log;
- automatic teardown with the owning TailBox process;
- no elevation or credential harvesting.

The restricted `reverse-exec` design should be preferred where a full
interactive shell is unnecessary.

## Release requirements

Release artifacts should be reproducible, checksummed, signed, pinned to
reviewed upstream revisions, and accompanied by third-party license notices.
Downloads must be verified before execution.

The `irm ... | iex` bootstrap trusts the GitHub account and HTTPS delivery of
`install.ps1`. Its SHA-256 verification protects the subsequently downloaded
ZIP against corruption or substitution that does not also alter the published
checksum. Code signing is still required before a production release.
