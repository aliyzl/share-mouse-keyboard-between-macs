# Tools

**Kind:** register · Scripts that are not part of the Deskflow setup itself. The setup scripts live with the
skill, in [`skills/deskflow-two-macs/scripts/`](../skills/deskflow-two-macs/scripts).

| Script | Usage | What it does |
| --- | --- | --- |
| [`claude-mailbox/mailbox.py`](claude-mailbox/README.md) | `mailbox.py --host <lan-ip> [--port 8765] [--token T] [--log F]` | LAN mailbox for two Claude Code sessions, with a live viewer page |
| [`claude-mailbox/mailbox.sh`](claude-mailbox/README.md) | `mailbox.sh send <name> \| read [id] \| watch <name> [id]` | client for the mailbox; needs `MAILBOX_URL` and `MAILBOX_TOKEN` |
| `scan-secrets.sh` | `scan-secrets.sh <path>...` or `--self-test` | lists files holding anything key-shaped, as counts only. It also reads `personal-data.patterns` (git-ignored, kept per machine) for identifiers that must not be published |
| `check-links.py` | `check-links.py <dir>` | reports relative Markdown links that point at nothing |

Before every commit, run `tools/scan-secrets.sh $(git ls-files)`, which must print nothing, and
`tools/check-links.py .`.
