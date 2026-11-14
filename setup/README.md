# Setup, step by step

**Kind:** runbook · **Verified:** 2026-11-14 with Deskflow 1.27.0, server on macOS 26.6 (Apple Silicon), client on
macOS 15.8 (Intel) · If Deskflow's own behaviour disagrees with this page, Deskflow is right, so please open an
issue.

This is the manual route. The [skill](../skills/deskflow-two-macs/SKILL.md) runs the same steps for you. Commands
are run from a clone of this repository; `S` is short for the scripts folder:

```bash
git clone https://github.com/aliyzl/share-mouse-keyboard-between-macs && cd share-mouse-keyboard-between-macs
S=skills/deskflow-two-macs/scripts
```

## How the pieces fit

| Piece | Where | Job |
| --- | --- | --- |
| Deskflow GUI (`Deskflow.app/Contents/MacOS/Deskflow`) | both Macs | holds the permissions, starts the core, shows trust prompts |
| `deskflow-core server` | the Mac with the keyboard and mouse | captures input at the screen edge and sends it over TLS on TCP 24800 |
| `deskflow-core client` | the other Mac | connects to the server and replays input |
| `~/Library/Deskflow/Deskflow.conf` | both | every setting; [format](../skills/deskflow-two-macs/references/settings-format.md) |
| `~/Library/Deskflow/deskflow-server.conf` | server | which screen sits on which side |
| a cable, ideally | between the two | keeps the pointer independent of Wi-Fi; [wired link](../skills/deskflow-two-macs/references/wired-link.md) |

## 0. Decide four things

| | Example | Note |
| --- | --- | --- |
| which Mac is the server | the iMac | the one whose keyboard and mouse you will use |
| where the client sits | `right` | the edge you push the pointer through: `right`, `left`, `up` or `down` |
| the two Deskflow names | `imac`, `macbook` | labels, not host names: letters, digits, `.`, `_` and `-` |
| the server's address as the client sees it | `192.168.77.1` | on the cable, if you use one; otherwise its Wi-Fi address |

## 1. Install (both Macs)

```bash
$S/install-deskflow.sh
```

```text
==> Release v1.27.0, asset deskflow-1.27.0-macos-arm64.dmg
==> Checking SHA-256
    sha256 dd21e79e…0c97 matches sums.txt and GitHub's asset digest
==> Checking the DMG's notarization
    source=Notarized Developer ID
==> Mounting (the DMG shows the GPL licence; it is accepted here)
==> Checking the app's signature
    signed by team 5QCJCX8C37, notarized
==> Installed deskflow-core v1.27.0, protocol v1.8
```

The script stops at the first failed check and installs nothing. Useful flags:

- `--download-only` verifies without installing;
- `--version 1.27.0` pins the release;
- `--force` replaces an existing copy.

If you already have Barrier, Synergy or Input Leap on either Mac, quit it and remove it from Login Items. An old
client still running keeps knocking on port 24800.

## 2. Write the settings (before the first launch)

Server:

```bash
$S/write-deskflow-config.py server --name imac --client macbook --side right
```

Client:

```bash
$S/write-deskflow-config.py client --name macbook --server 192.168.77.1
```

Each command backs up any existing `Deskflow.conf` and refuses while Deskflow is running. Without this step you
can set the same things in the app's window. The server's layout, though, must then be built in its grid. The
older `section: screens` file format is ignored by 1.27.

## 3. Start, server first

```bash
open -a Deskflow
```

If `open` fails with error `-10810`, register the app once with
`/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Deskflow.app`.

Do not start `deskflow-core` from Terminal. macOS would check the terminal's permissions instead of Deskflow's.

## 4. Grant permissions

All of these are in **System Settings → Privacy & Security**:

| Mac | Section | Symptom if missing |
| --- | --- | --- |
| both | **Accessibility**: turn on Deskflow | the app quits at once |
| server | **Input Monitoring**: turn on Deskflow, if it is listed | the pointer will not cross the edge |
| client, macOS 15+ | **Local Network**: turn on Deskflow | the client never connects; `lsof` shows `SYN_SENT` |

After changing a permission, quit Deskflow and start it again: `kill -TERM` both processes, then `open -a Deskflow`.

## 5. Trust each other

On the first connection, the client asks you to trust the server's fingerprint, and the server may ask about the
client's. Before accepting, read the other Mac's own fingerprint:

```bash
$S/check-deskflow.sh | grep 'own certificate'     # run on the OTHER Mac
```

Accept only if they match.

## 6. Check and test

```bash
$S/check-deskflow.sh       # both Macs: VERDICT: OK
```

Then test:

1. push the pointer across the shared edge and back;
2. type on the client, including any second keyboard layout (choose the layout on the client);
3. copy on one Mac and paste on the other, both ways;
4. move the pointer quickly in circles on the client. If it trails behind your hand, go to step 7.

## 7. If the pointer lags

```bash
$S/measure-latency.sh <client-ip>        # from the server
```

| You see | Meaning | Do |
| --- | --- | --- |
| under 5 ms | the network is fine | look elsewhere: CPU (`top`), the log |
| tens to hundreds of ms, router just as slow | the Wi-Fi path | [use a cable](../skills/deskflow-two-macs/references/wired-link.md) |
| a falling staircase (900, 700, 500, …) | a radio holding packets back | a cable; see [the report](../reports/2026-11-14-wifi-lag/README.md) |

When something else fails, the log line is probably in
[troubleshooting](../skills/deskflow-two-macs/references/troubleshooting.md).

## Undo everything

```bash
pkill -TERM -f /Applications/Deskflow.app/Contents/MacOS/deskflow-core
pkill -TERM -f /Applications/Deskflow.app/Contents/MacOS/Deskflow
rm -rf /Applications/Deskflow.app ~/Library/Deskflow
```

Then remove Deskflow from Accessibility, Input Monitoring and Local Network in System Settings. If you assigned
cable addresses, undo them as described in the wired-link guide.
