# Pinned upstream sources

The native backend is currently developed against:

| Component | Revision | License |
| --- | --- | --- |
| Tailscale | `v1.102.0` / `35283c95445fb198af1ce708dac05714bdfaa037` | BSD-3-Clause |
| Go | `1.26.5` | BSD-3-Clause |
| Rust | stable, edition 2024 | MIT OR Apache-2.0 |

The preserved LiteBox experiment used:

| Component | Revision | License |
| --- | --- | --- |
| Microsoft LiteBox | `6a03ec80f065d2a66b937bde3d6f0708d282ca27` | MIT |
| libwgslirpy | `6805933f3e6f88f3cd8d1106a135d7d53eb198ea` | MIT OR Apache-2.0 |

Upstream source code is not vendored in this repository. Build tooling should
consume the pinned Go module and include corresponding upstream notices in
distributed artifacts. LiteBox patches are retained as experimental history.
