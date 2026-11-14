---
name: deskflow-two-macs
description: Share one Mac's keyboard and mouse with a second Mac using Deskflow 1.27, the open-source software KVM that succeeds Synergy, Barrier and Input Leap, when Apple's Universal Control is unavailable (for example without two-factor authentication, or across Apple IDs). Use when the user wants to control two Macs with one keyboard and mouse, install or configure a Deskflow server or client on macOS, or fix a Deskflow pointer that lags, will not connect, or will not start.
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/check-deskflow.sh) Bash(${CLAUDE_SKILL_DIR}/scripts/check-deskflow.sh --share) Bash(${CLAUDE_SKILL_DIR}/scripts/measure-latency.sh *)
---

# Deskflow between two Macs

You are setting up keyboard and mouse sharing between two Macs. The **server** is the Mac whose keyboard and
mouse are used. The **client** is the other Mac. Every step below was verified with Deskflow 1.27.0.

The scripts sit next to this file, in `${CLAUDE_SKILL_DIR}/scripts/`; the reference files call that folder
`<skill>/scripts/`. Run the scripts directly, as written below, so the pre-approved read-only checks match.
Read [references/troubleshooting.md](references/troubleshooting.md) as soon as anything fails, before you guess.

## Ground rules

- **Do not install anything until the person has agreed to the plan.** Installing Deskflow and granting it
  Accessibility gives it control of keyboard input.
- **Universal Control comes first.** If both Macs share an Apple ID with two-factor authentication, Universal
  Control needs no install. Say so, and continue only if it is not available or not wanted.
- **The clicks are the person's.** You cannot grant macOS privacy permissions, accept a TLS fingerprint or answer a
  password prompt. Tell the person exactly where to click, or ask them to run a command themselves (in Claude
  Code, by typing it after `!`). Then verify with the check script.
- **Never start `deskflow-core` from your shell.** macOS charges the Accessibility check to the terminal and
  the core exits. Always use `open -a Deskflow`.
- **Stop Deskflow with `kill -TERM`** on both processes (`/Applications/Deskflow.app/Contents/MacOS/Deskflow`
  and `.../deskflow-core`), and check both are gone. AppleScript `quit` is refused, the core can outlive the GUI,
  and `pgrep -f deskflow` misses the GUI.
- **Leave existing network settings alone** unless the person agrees. When an interface already has a manual
  address, fit around it.
- **`check-deskflow.sh` output identifies the machine.** Use `--share` for anything that will be posted publicly.

## 1. Agree the layout

Settle these four things, using sensible defaults and asking only what you cannot see:

| Setting | Default |
| --- | --- |
| server Mac | the one this session runs on, if its keyboard and mouse are the ones to share |
| client side | `right` of the server (also `left`, `up`, `down`) |
| Deskflow names | short lowercase labels such as `imac` and `macbook`: letters, digits, `.`, `_` and `-`, starting and ending with a letter or digit |
| link | a direct cable if available; otherwise the LAN (measure it in step 6) |

**If a Claude session runs on the other Mac too,** coordinate with it directly rather than relaying through the
person. The repository includes a small LAN mailbox for this. When the skill is installed as a plugin or used from
a clone, it is at `${CLAUDE_SKILL_DIR}/../../tools/claude-mailbox/`. Otherwise get it from
github.com/aliyzl/share-mouse-keyboard-between-macs. It needs `python3` on one Mac and only `curl` on the other.
Test its watcher end to end before relying on it.

## 2. Install, on each Mac

```bash
${CLAUDE_SKILL_DIR}/scripts/install-deskflow.sh
```

The script needs the Xcode Command Line Tools (`xcode-select --install`) and installs the verified release,
1.27.0 (`--latest` for the newest). It:

1. picks the DMG for the hardware (`arm64` or `x86_64`, even under Rosetta);
2. checks the SHA-256 against `sums.txt` and against GitHub's asset digest;
3. checks the DMG's notarization;
4. checks the app's signing team (`5QCJCX8C37`);
5. accepts the GPL licence prompt, copies the app to `/Applications`, and registers it with LaunchServices.

It refuses before downloading if Deskflow is running or already installed (`--force` replaces it). Any failed check
stops it before anything is installed. `--download-only` verifies without installing.

## 3. Write the settings, before the first launch

```bash
# server
${CLAUDE_SKILL_DIR}/scripts/write-deskflow-config.py server --name imac --client macbook --side right
# client (use the server's address on the link you chose)
${CLAUDE_SKILL_DIR}/scripts/write-deskflow-config.py client --name macbook --server <server-ip>
```

This writes `~/Library/Deskflow/Deskflow.conf` in the 1.27 format:

- mode, name, and start-with-GUI;
- file logging to `~/Library/Deskflow/deskflow.log`;
- on the server, the layout file, and exactly one `[computer_<name>]` group per computer.

It backs up each file it replaces, refuses while Deskflow is running, and rejects malformed names and addresses.
The format is explained in [references/settings-format.md](references/settings-format.md).

## 4. Start and grant permissions

Start the server first, then the client: `open -a Deskflow`. The client retries every few seconds, so the order is
not critical. If `open` fails with error `-10810`, register the app (the `lsregister -f` command is in the
troubleshooting file) and try again.

Ask the person to allow Deskflow in **System Settings → Privacy & Security**:

- **Accessibility**, on both Macs. Without it the app quits immediately.
- **Input Monitoring**, on the server, if it is listed or prompted. The original client ran without it (not tested
  either way).
- **Local Network**, on the client (macOS 15 and later). Without it the connection hangs in `SYN_SENT`. Once it is
  granted, the running client connects within seconds.

On the first connection the client asks to trust the server's TLS fingerprint, and the server may ask about the
client's. Run `check-deskflow.sh` on the other Mac to read its fingerprint, compare, and only then tell the person to
accept.

Finally, so that a restart does not silently break the setup, offer to add Deskflow to Login Items on both Macs.
With the person's agreement:

```bash
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Deskflow.app", hidden:false}'
osascript -e 'tell application "System Events" to get the {name, path} of every login item'    # check
```

macOS may ask the person to let the terminal control System Events. The manual route is System Settings → General
→ Login Items → **+**.

## 5. Verify

```bash
${CLAUDE_SKILL_DIR}/scripts/check-deskflow.sh
```

Run it on both Macs and expect `VERDICT: OK`. Then ask the person to test four things:

1. move the pointer across the shared edge, in both directions;
2. type on the client, including any non-Latin layout, selected on the client;
3. copy on one Mac and paste on the other, in both directions;
4. check that the pointer keeps up with the hand.

The server log (`~/Library/Deskflow/deskflow.log`) shows each `switch from "<a>" to "<b>"`.

## 6. If the pointer lags

```bash
${CLAUDE_SKILL_DIR}/scripts/measure-latency.sh <other-mac-ip>
```

Read the result as follows:

| Result | Verdict |
| --- | --- |
| under ~5 ms | fine |
| above ~20 ms | the person will feel it; the script then exits 1 |
| a falling staircase of times (900, 700, 500, 300, 100, 900…) | a radio is holding packets and releasing them in bursts |
| the router is as slow as the other Mac | the Wi-Fi path is at fault, not Deskflow |

Do not run a Wi-Fi scan while measuring.

The reliable fix is a direct cable between the Macs. Follow [references/wired-link.md](references/wired-link.md).
After the cable is in:

1. give each end a manual address on an unused private `/24`;
2. rewrite the client's settings with the new server address;
3. measure again (expect under 1 ms).
