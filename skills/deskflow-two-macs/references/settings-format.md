# Deskflow 1.27 settings on macOS

**Kind:** reference · **Verified against:** Deskflow 1.27.0 (`src/lib/common/Settings.h` and `.cpp` at tag
`v1.27.0`, and a running server and client) · If Deskflow disagrees with this page, Deskflow is right, so update
the page.

## Where things live

| File | Holds |
| --- | --- |
| `~/Library/Deskflow/Deskflow.conf` | every setting, in Qt INI format. The GUI and the core both read it, and the GUI reloads it when it changes on disk |
| `~/Library/Deskflow/deskflow-server.conf` | the server's layout (`section: links`) and options, when `server/externalConfig=true` |
| `~/Library/Deskflow/tls/deskflow.pem` | this Mac's TLS certificate and key, created on first start. **Never share or commit it** |
| `~/Library/Deskflow/tls/trusted-servers` | on a client: the server fingerprints it has accepted |
| `~/Library/Deskflow/tls/trusted-clients` | on a server: the client fingerprints it has accepted |
| `~/Library/Deskflow/deskflow.log` | the log, as set up by `write-deskflow-config.py` (`log/toFile=true`, `log/file` pointing here). With `log/toFile=true` and no `log/file`, 1.27 writes `~/deskflow.log` |
| `~/Library/Preferences/State/Deskflow.state` | window geometry and similar state, kept apart from the settings |

`XDG_CONFIG_HOME`, if set, moves the settings file to `$XDG_CONFIG_HOME/Deskflow/Deskflow.conf`.

## The keys that matter

| Key | Values | Notes |
| --- | --- | --- |
| `core/coreMode` | `1` client, `2` server (`0` none) | an enum, stored as its number |
| `core/computerName` | this Mac's Deskflow name | defaults to the host name. Keep it short, using letters, digits, `.`, `_` and `-` |
| `core/port` | `24800` | the default; change it on both sides or neither |
| `gui/startCoreWithGui` | `true` | start the server or client as soon as the app opens |
| `client/remoteHost` | the server's IP address or host name | client only |
| `server/externalConfig` | `true` | use the layout file below instead of the GUI's grid |
| `server/externalConfigFile` | an absolute path | the layout file |
| `server/enableClipboard` | `true` (default) | clipboard sharing |
| `security/tlsEnabled` | `true` (default) | |
| `security/checkPeerFingerprints` | `true` (default) | keep it on |
| `log/toFile`, `log/file`, `log/level` | `true`, a path, `INFO` or `DEBUG` | the log the check script tails |
| `[computer_<name>]` → `name=<name>` | one group per computer in the layout | **required on the server**; see below |

## The 1.27 change that breaks older guides

Before 1.27, the server's config file listed its screens:

```text
section: screens
	imac:
	macbook:
end
```

1.27 ignores that section. It logs *"Your server config has a screen section. Screens have moved to the general
config this section will not be parsed."* Then it fails on the first link with
*"unknown computer name"* and the core exits with code 4. The server now learns its computers from groups in
`Deskflow.conf`:

```ini
[computer_imac]
name=imac

[computer_macbook]
name=macbook
```

The layout file keeps only the links and options:

```text
section: links
	imac:
		right = macbook
	macbook:
		left = imac
end

section: options
	clipboardSharing = true
end
```

## A complete pair, as written by `write-deskflow-config.py`

Server `Deskflow.conf`:

```ini
[core]
coreMode=2
computerName=imac

[gui]
startCoreWithGui=true
shownServerFirstStartMessage=true

[log]
toFile=true
file=/Users/<you>/Library/Deskflow/deskflow.log
level=INFO

[server]
enableClipboard=true
externalConfig=true
externalConfigFile=/Users/<you>/Library/Deskflow/deskflow-server.conf

[computer_imac]
name=imac

[computer_macbook]
name=macbook
```

Client `Deskflow.conf`:

```ini
[core]
coreMode=1
computerName=macbook

[gui]
startCoreWithGui=true

[log]
toFile=true
file=/Users/<you>/Library/Deskflow/deskflow.log
level=INFO

[client]
remoteHost=192.168.77.1
```

The GUI adds its own keys on first start, such as `core/lastVersion` and an `[internalConfig]` group. Leave them.

## Trusted fingerprints

Each line in `trusted-servers` or `trusted-clients` reads `v2:sha256:<64 lowercase hex digits>`. The hex is the
SHA-256 of the peer's certificate without colons:

```bash
openssl x509 -in ~/Library/Deskflow/tls/deskflow.pem -noout -fingerprint -sha256   # on the peer
```

Accepting the dialog writes the line for you. Compare the value with the peer's own output before accepting.
