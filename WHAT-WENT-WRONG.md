# What went wrong

**Kind:** lessons · **Covers:** the original setup on 2026-11-14 (Tehran, +0330) · Sorted by what it cost. Each
entry gives what happened, why it happened, and the rule that now prevents it. The rules are already built into
the scripts and the skill. They are written down here so the reasoning survives.

The setup was done by two Claude Code sessions, one on each Mac, coordinating through
[`tools/claude-mailbox`](tools/claude-mailbox/README.md), with one person making the clicks.

---

## 1. The first working setup was unusable: the pointer lagged by seconds (about 25 minutes)

**What happened:** Deskflow connected, and the pointer, typing and clipboard all worked. But the pointer on the
client trailed the hand badly. Round trips from the server to the client over Wi-Fi measured 500–2,800 ms.

**Why:** the Wi-Fi path, not Deskflow:

- Both Macs were on a crowded 2.4 GHz channel, shared with two neighbouring networks that were stronger than
  the home router.
- At the decisive moment, the server's own radio was the slow leg. The server took 542 ms to reach the router,
  while the client took 5 ms.
- The server's round trips formed a falling staircase: packets were held and released together about once a
  second.
- The server's mouse is Bluetooth. Bluetooth shares the 2.4 GHz radio, and it is busiest exactly when the person
  is moving the mouse to control the other Mac. That is the leading explanation, but it was not proven. See
  [the report](reports/2026-11-14-wifi-lag/README.md).

**Rules:**

1. Measure latency before blaming the software: `measure-latency.sh` to the other Mac **and** to the router.
2. Rule each suspect in or out with one change at a time. Stopping Deskflow's core left the router latency
   unchanged, so Deskflow was ruled out.
3. For a keyboard and mouse, use a cable between the Macs whenever possible. It measured 0.6 ms.

## 2. The message watcher was silently broken, and a reply went unread (about 5 minutes)

**What happened:** the iMac session built the mailbox and a background watcher that announced new messages. The
watcher's Python used a backslash inside an f-string expression, which the machine's Python 3.9 rejects. Every
poll failed, and the error went to stderr, which the watcher did not report. The MacBook's first reply sat unseen
until the mailbox was read by hand. Meanwhile the person had been told the channel was working.

**Why:** the watcher was tested only on its happy path (the server answered), never end to end (a message from
the other side surfaces).

**Rules:**

1. Test a watcher by sending it a real event and seeing it arrive, before reporting that it works.
2. Route a watcher's errors into the same stream as its events. A watcher that fails quietly looks exactly like
   one with nothing to report.
3. Keep scripts compatible with the oldest interpreter on either machine; macOS's `/usr/bin/python3` was 3.9.

## 3. The 1.27 settings format: the first server start failed (about 10 minutes)

**What happened:** the server's config file listed its computers in `section: screens`, as every older guide
shows. Deskflow 1.27 ignored the section, then failed with `unknown computer name` and exit code 4.

**Why:** 1.27 moved computer definitions into `Deskflow.conf` as `[computer_<name>]` groups.

**Rules:**

1. Read the settings code of the exact release (`src/lib/common/Settings.h` at the tag) before writing its
   settings.
2. `write-deskflow-config.py` writes the 1.27 layout, and `check-deskflow.sh` flags `section: screens`.

## 4. The client could not connect until Local Network was allowed (about 5 minutes)

**What happened:** the client's connections to the server sat in `SYN_SENT`, while `curl` from Terminal on the same
Mac reached the server fine.

**Why:** macOS 15 grants LAN access per app. Terminal had it; Deskflow did not.

**Rule:** on a macOS 15+ client, ask for Local Network for Deskflow as part of setup, not after a failure. Never
treat a successful shell test as proof that an app can connect.

## 5. A "stopped" Deskflow was still running, so the server stayed down after the test (about 2 minutes)

**What happened:** to test whether Deskflow caused the lag, its processes were stopped with AppleScript `quit` and
`pkill -f deskflow-core`. The check `pgrep -lf deskflow` printed nothing, so the GUI looked stopped. It was not:
the GUI's binary is `Deskflow` with a capital D, and AppleScript `quit` is refused. The later `open -a Deskflow`
only brought the running GUI forward and did not restart the killed core.

**Why:** a case-sensitive match, and trusting a quit command without checking its effect.

**Rules:**

1. Stop Deskflow with `kill -TERM` on both full paths, and check both are gone.
2. After a restart, check for `deskflow-core` and the listening port, not only the app.

## 6. The first cable carried no data (about 5 minutes)

**What happened:** a USB-C cable joined the two Macs, but neither showed a Thunderbolt link, and System Information
read "No device connected" on every port.

**Why:** it was a charging cable. Thunderbolt Bridge needs a Thunderbolt 3/4 or USB4 cable. Two Macs joined by a
plain USB cable are two hosts, so no link forms.

**Rules:**

1. Name the cable precisely when asking for one: ⚡ or "40" on the plug.
2. Offer Ethernet, with a USB-C adapter where needed, as the alternative. That is what was used in the end.

## Small slips

- **`yes | hdiutil` killed the install script with exit 141.** `yes` dies of SIGPIPE when `hdiutil` stops reading,
  and `pipefail` turned that into a failure. **How it was caught:** the first `--download-only` test run. **Rule:**
  disable `pipefail` inside that one command substitution.
- **Port probes looked like a broken client.** `nc -z` from the client produced `failed to accept secure socket` on
  the server every few seconds. **How it was caught:** the client session recognised its own probe. **Rule:**
  don't probe the Deskflow port while diagnosing TLS; read `lsof` on the server instead.
- **A Wi-Fi scan inflated the first latency figures on the client.** `system_profiler SPAirPortDataType` ran at the
  same time as `ping`. **How it was caught:** the client session repeated the measurement on its own and discarded
  the first figures. **Rule:** measure first and scan afterwards.
- **`raw.githubusercontent.com` was blocked on the server's network** while `api.github.com` worked. **Rule:** fetch
  source files through the contents API.
- **The server's Ethernet service already had an old manual address** (a `/16` in `192.168.0.0/16`). **How it was
  caught:** `networksetup -getinfo Ethernet` when the cable came up. **Rule:** look at an interface's existing
  configuration before assigning addresses. Fit around it rather than overwrite it without asking.
