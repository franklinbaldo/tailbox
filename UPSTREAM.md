# Pinned upstream sources

TailBox is currently developed and tested against these exact revisions:

| Component | Revision | License |
| --- | --- | --- |
| Microsoft LiteBox | `6a03ec80f065d2a66b937bde3d6f0708d282ca27` | MIT |
| Tailscale | `v1.98.9` / `6c167d40fa37aeb51afa7ff336730670ea4762bf` | BSD-3-Clause |
| Go | `1.26.5` | BSD-3-Clause |
| libwgslirpy | `6805933f3e6f88f3cd8d1106a135d7d53eb198ea` | MIT OR Apache-2.0 |

Upstream source code is not vendored in this repository. Build tooling should
fetch and verify pinned revisions, apply the patches in `patches/`, and include
the corresponding upstream notices in distributed artifacts.
