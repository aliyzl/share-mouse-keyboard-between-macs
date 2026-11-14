# Troubleshooting Deskflow between two Macs

**Kind:** reference · **Verified against:** Deskflow 1.27.0 on macOS 26.6 (server) and 15.8 (client),
2026-11-14 · Each entry is something that actually happened during the original setup. Start with
`check-deskflow.sh` on both Macs; it points at most of these.

Log lines are quoted exactly. `write-deskflow-config.py` turns on the log file at `~/Library/Deskflow/deskflow.log`.
Without it, Deskflow logs only to its window, or to `~/deskflow.log` if `log/toFile=true` is set with no
`log/file`. `<skill>` is this skill's folder: `skills/deskflow-two-macs` in a clone of the repository.

## Install

### `hdiutil: attach canceled`

**Why:** the Deskflow DMG carries a Software License Agreement (the GPL). Without a terminal to answer it,
`hdiutil` cancels.

**Fix:** answer on stdin with `yes | hdiutil attach -nobrowse -readonly -noautoopen <dmg>`. Under
`set -o pipefail`, `yes` dies of SIGPIPE (exit 141) when `hdiutil` stops reading, which aborts the script. Turn
`pipefail` off for that one command. `install-deskflow.sh` does both.

### `open` fails with `_LSOpenURLsWithCompletionHandler() ... error -10810`

**Why:** the app was copied into `/Applications` by a script and LaunchServices had not registered it yet.

**Fix:** register it, then open it again:

```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Deskflow.app
```

### Downloads from `raw.githubusercontent.com` fail (`Connection reset by peer`)

**Why:** some networks and VPN exits block that host, while `github.com` and `api.github.com` still work.

**Fix:** the install script needs only `api.github.com` and `github.com`. To read a file from the Deskflow
source, use the contents API:

```bash
curl -H "Accept: application/vnd.github.raw" https://api.github.com/repos/deskflow/deskflow/contents/<path>?ref=v1.27.0
```

## Start

### The app quits immediately (exit code 1)

**Why:** Deskflow has no Accessibility permission. The GUI checks for it at start (`checkMacAssistiveDevices`) and
exits.

**Fix:** turn on Deskflow in System Settings → Privacy & Security → Accessibility, then `open -a Deskflow` again.
If it is already on, toggle it off and on: a replaced app keeps the old entry but not the old trust (this is common
macOS behaviour, not something tested here).

### `FATAL: a runtime error occurred: assistive devices does not trust this process`

**Why:** `deskflow-core` was started from a terminal. macOS charges the Accessibility check to the app that
launched it, so the terminal or editor (Terminal, VS Code and the like) is checked, not Deskflow.

**Fix:** start Deskflow only with `open -a Deskflow`; the app starts the core itself.

### `Your server config has a screen section. Screens have moved to the general config this section will not be parsed.`

Then `cannot read configuration ... unknown computer name "<name>"`, `FATAL: deskflow-core: failed to load
config`, `core stopped with error code: 4`.

**Why:** in 1.27, computers are declared in `Deskflow.conf`, not in the server config file.

**Fix:** add a `[computer_<name>]` group with `name=<name>` for every computer in the layout, and delete
`section: screens`. `write-deskflow-config.py server ...` does this. See [settings-format.md](settings-format.md).

### Deskflow will not quit

`osascript -e 'tell application "Deskflow" to quit'` fails with *"execution error: Deskflow got an error: User
canceled. (-128)"*, even with `gui/closeReminder=false`, or it leaves the app running in the menu bar. Once,
`deskflow-core` also kept running after the GUI had gone.

**Fix:** `kill -TERM` both processes by full path:

```bash
pkill -TERM -f /Applications/Deskflow.app/Contents/MacOS/Deskflow
pkill -TERM -f /Applications/Deskflow.app/Contents/MacOS/deskflow-core
pgrep -lf /Applications/Deskflow.app || echo "Deskflow stopped"
```

Note that `pgrep -f deskflow` is case-sensitive and does not match the GUI, whose binary is `Deskflow`. macOS
`pgrep` has no `-E`; use `pgrep -il 'barrier|synergy|deskflow'` for a broad look. One test
during the original setup concluded "stopped" while the GUI was still alive. The relaunch that followed then only
brought the running app to the front, and the server stayed down until the GUI was killed.

## Connect

### The client never connects: its connection sits in `SYN_SENT`

`curl` or `nc` from Terminal reaches the server fine.

**Why:** on macOS 15 and later, each app needs **Local Network** permission to open LAN connections. Terminal has
its own grant, which is why tests from a shell mislead.

**Fix:** turn on Deskflow in System Settings → Privacy & Security → Local Network on the client. The running client
connects within seconds; no restart is needed. Check with `lsof -nP -a -p $(pgrep -f MacOS/deskflow-core) -iTCP`.
The server needs no Local Network permission to listen.

### `ERROR: failed to accept secure socket` every few seconds on the server

Sometimes it reads `tls error occurred (system call failure)` instead.

**Why:** something is opening TCP 24800 without completing a TLS handshake. In the original setup it was a port
probe (`nc -z <server> 24800`) run from the client. An old Barrier or Synergy client still running on the other
Mac causes the same thing.

**Fix:** stop the probe, and quit any old client that is running (`pgrep -il 'barrier|synergy'`). These lines do
not come from your Deskflow client. On the original client, Barrier 2.4.0 and Synergy 3.2.1 were installed but not
running, and caused no conflict.

### `WARNING: fingerprint does not match trusted fingerprint`

**Why:** the peer's certificate is not the one recorded in `trusted-servers` or `trusted-clients`. That happens
when the peer regenerated its certificate, or when something else is answering on that address.

**Fix:** compare `openssl x509 -in ~/Library/Deskflow/tls/deskflow.pem -noout -fingerprint -sha256` on the peer
with the stored line (`v2:sha256:<hex>`). Replace the line only if they match the Mac you expect.

### `saying hello as Barrier, protocol v1.8`

This is normal. In 1.27 the server's default network protocol is Barrier's, and a 1.27 client understands it.

### `accepted client connection` then at once `new client disconnected`

In the original setup this repeated for about a minute and stopped once two things had happened on the client:
the server's fingerprint was accepted, and Local Network was allowed. Which of the two ended it was not isolated.
Check both.

### `WARNING: cursor may not be visible`

This is harmless. The server hides its cursor while the pointer is on the client.

## Lag

### The pointer on the client trails the hand by half a second or more

Measure before changing anything:

```bash
<skill>/scripts/measure-latency.sh <other-mac-ip>
```

The script prints each round trip, then the same to the router. In the original setup:

| Path | Round trips |
| --- | --- |
| between the Macs over Wi-Fi | averages of 460–1,000 ms; single round trips up to 2.8 s |
| server to router | averages of 517–579 ms |
| client to router | 510 ms average at 23:16; 5 ms at 23:22, when the server still needed 542 ms |
| between the Macs over a cable | 0.6 ms average |

Deskflow was ruled out by stopping its core: the router latency did not change.

**Fix:** a direct cable; see [wired-link.md](wired-link.md). The investigation is written up in the
repository's `reports/2026-11-14-wifi-lag/`.

**Do not** run `system_profiler SPAirPortDataType` or any other Wi-Fi scan while measuring. A scan takes the
radio off its channel and inflates the numbers.

### Deskflow does not start after a restart

The cable address and the settings survive a restart, but Deskflow is not in Login Items, so nothing connects until
someone opens it. Add it to Login Items on both Macs, either in System Settings → General → Login Items or with:

```bash
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Deskflow.app", hidden:false}'
osascript -e 'tell application "System Events" to get the {name, path} of every login item'    # check
```

After `open -a Deskflow`, the original client reconnected over the cable in under 8 seconds.

### Wi-Fi names show as `<redacted>`

On macOS 15 and later, `system_profiler SPAirPortDataType` hides network names from apps without Location Services
permission. Channel, band and signal are still shown, which is all a latency diagnosis needs.

### A falling staircase of round-trip times

For example `962 757 552 352 150 979 774 ...` with one ping every 0.2 s. The radio is holding packets and
releasing them together about once a second. The cause is power saving, off-channel time (scans, AWDL, Bluetooth
coexistence on a shared 2.4 GHz radio), or a congested channel. Keeping the radio busy with a second ping stream
did not help in the original case, which rules out simple power saving.
