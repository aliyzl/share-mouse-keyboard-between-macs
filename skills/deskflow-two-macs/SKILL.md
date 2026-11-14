---
name: deskflow-two-macs
description: Share one Mac's keyboard and mouse with a second Mac using Deskflow 1.27 (the open-source successor of Synergy and Barrier) when Apple's Universal Control is unavailable, for example without two-factor authentication or across Apple IDs. Use when the user wants to control two Macs with one keyboard and mouse, install or configure a Deskflow server or client on macOS, or fix a Deskflow pointer that lags, will not connect, or will not start.
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/check-deskflow.sh) Bash(${CLAUDE_SKILL_DIR}/scripts/measure-latency.sh *)
---

# Deskflow between two Macs

You are setting up keyboard and mouse sharing between two Macs. The **server** is the Mac whose keyboard and
mouse are used. The **client** is the other Mac. Every step below was verified with Deskflow 1.27.0. Read
[references/troubleshooting.md](references/troubleshooting.md) as soon as anything fails, before you guess.

## Ground rules

- **Do not install anything until the person has agreed to the plan.** Installing Deskflow and granting it
  Accessibility gives it control of keyboard input.
- **Universal Control comes first.** If both Macs share an Apple ID with two-factor authentication, Universal
  Control needs no install. Say so, and continue only if it is not available or not wanted.
- **The clicks are the person's.** You cannot grant macOS privacy permissions or accept a TLS fingerprint. Tell
  the person exactly where to click, then verify with the check script.
- **Never start `deskflow-core` from your shell.** macOS charges the Accessibility check to the terminal and
  the core exits. Always use `open -a Deskflow`.
- **Stop Deskflow with `kill -TERM`** on both processes (`/Applications/Deskflow.app/Contents/MacOS/Deskflow`
  and `.../deskflow-core`). AppleScript `quit` is refused, and `pgrep -f deskflow` misses the GUI.
- **Leave existing network settings alone** unless the person agrees. When an interface already has a manual
  address, fit around it.

## 1. Agree the layout

Settle these four things, using sensible defaults and asking only what you cannot see:

| Setting | Default |
| --- | --- |
| server Mac | the one this session runs on, if its keyboard and mouse are the ones to share |
| client side | `right` of the server (also `left`, `up`, `down`) |
| Deskflow names | short lowercase labels such as `imac` and `macbook`, using letters, digits, `.`, `_` and `-` |
| link | a direct cable if available; otherwise the LAN (measure it in step 6) |

If a Claude session is running on the other Mac too, coordinate with it rather than relaying through the person.
`tools/claude-mailbox` in this skill's repository (github.com/aliyzl/share-mouse-keyboard-between-macs) is a
tiny LAN mailbox for exactly that. It needs `python3` on one Mac and `curl` on the other.

## 2. Install, on each Mac

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/install-deskflow.sh"            # add --version 1.27.0 to pin
```

The script picks the DMG for the CPU (`arm64` or `x86_64`). It checks the SHA-256 against both `sums.txt` and
GitHub's asset digest, checks that the DMG is notarized, and checks the app's signing team (`5QCJCX8C37`). It then
accepts the GPL licence prompt, copies the app to `/Applications`, and registers it with LaunchServices. Any
failed check stops it before anything is installed. Run `--download-only` to verify without installing.

## 3. Write the settings, before the first launch

```bash
# server
python3 "${CLAUDE_SKILL_DIR}/scripts/write-deskflow-config.py" server --name imac --client macbook --side right
# client (use the server's address on the link you chose)
python3 "${CLAUDE_SKILL_DIR}/scripts/write-deskflow-config.py" client --name macbook --server <server-ip>
```

This writes `~/Library/Deskflow/Deskflow.conf` in the 1.27 format (mode, name, start-with-GUI), plus the server's
layout file and its `[computer_<name>]` groups. It backs up any existing file and refuses while Deskflow is
running. The format is explained in [references/settings-format.md](references/settings-format.md).

## 4. Start and grant permissions

Start the server first, then the client: `open -a Deskflow`. If `open` fails with error `-10810`, run
`lsregister -f /Applications/Deskflow.app` (full path in the troubleshooting file) and try again.

Ask the person to allow Deskflow in **System Settings → Privacy & Security**:

- **Accessibility**, on both Macs. Without it the app quits immediately.
- **Input Monitoring**, on the server, if it is listed or prompted.
- **Local Network**, on the client (macOS 15 and later). Without it the connection hangs in `SYN_SENT`.

On the first connection each side asks to trust the other's TLS fingerprint. Run `check-deskflow.sh` on the
other Mac to read its fingerprint, compare the two, and only then tell the person to accept.

## 5. Verify

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/check-deskflow.sh"     # on both Macs; expect "VERDICT: OK"
```

Then ask the person to test four things:

1. move the pointer across the shared edge, in both directions;
2. type on the client, including any non-Latin layout, selected on the client;
3. copy on one Mac and paste on the other, in both directions;
4. check that the pointer keeps up with the hand.

The server log (`~/Library/Deskflow/deskflow.log` when `log/toFile=true`) shows each
`switch from "<a>" to "<b>"`.

## 6. If the pointer lags

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/measure-latency.sh" <other-mac-ip>
```

Read the result as follows:

| Result | Verdict |
| --- | --- |
| under ~5 ms | fine |
| above ~20 ms | the person will feel it |
| a falling staircase of times (900, 700, 500, 300, 100, 900…) | a radio is holding packets and releasing them in bursts |
| the router is as slow as the other Mac | the Wi-Fi path is at fault, not Deskflow |

Do not run a Wi-Fi scan while measuring.

The reliable fix is a direct cable between the Macs. Follow [references/wired-link.md](references/wired-link.md).
After the cable is in:

1. give each end a manual address on an unused private `/24`;
2. rewrite the client's settings with the new server address;
3. measure again (expect under 1 ms).
