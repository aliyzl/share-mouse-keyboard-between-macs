# Third-party software

**Kind:** reference · **Last checked:** 2026-11-14

This repository contains no third-party code or binaries. `install-deskflow.sh` downloads Deskflow from its own
GitHub releases at install time and verifies it there.

## Deskflow

| | |
| --- | --- |
| Project | [deskflow/deskflow](https://github.com/deskflow/deskflow) |
| Licence | GPL-2.0 (the DMG shows it as a licence agreement on mount) |
| Release verified | `v1.27.0`, published 2026-10-01 |
| Signing | Developer ID Application, team `5QCJCX8C37`; DMG notarized |

| Asset | SHA-256 (matches the release's `sums.txt` and GitHub's asset digest) |
| --- | --- |
| `deskflow-1.27.0-macos-arm64.dmg` | `dd21e79e566314394214906d3338c505d337af536fc580c022ee3fadffad0c97` |
| `deskflow-1.27.0-macos-x86_64.dmg` | `8aca3c77a1b16b9a3d6b8a380e5e38a0e6abf6d241bb32dcf3cf8b67abbff5d8` |

The install script does not hard-code these sums. For any release, it reads them from that release's `sums.txt`
and GitHub's digest. They are listed here so a reader can compare the verified build with a later one.

## Copied from the owner's own standard

`tools/scan-secrets.sh` and `tools/check-links.py` come unchanged from
[aliyzl/claude-code-workspace-standard](https://github.com/aliyzl/claude-code-workspace-standard) (MIT).
