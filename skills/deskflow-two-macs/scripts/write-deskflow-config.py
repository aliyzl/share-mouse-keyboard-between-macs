#!/usr/bin/env python3
"""Write Deskflow 1.27 settings for a server or a client Mac, before the first launch.

Usage:
  write-deskflow-config.py server --name NAME --client NAME [--side right|left|up|down] [--config-dir DIR]
  write-deskflow-config.py client --name NAME --server HOST [--config-dir DIR]

Deskflow 1.27 keeps its settings in ~/Library/Deskflow/Deskflow.conf (Qt INI format). Writing them
here means the app starts in the right mode and nothing has to be picked in its window. The script
edits only the keys it owns and keeps every other line, and it backs up every file it replaces. It
also turns on the log file (<config-dir>/deskflow.log), which troubleshooting relies on.

Two facts about 1.27 that this script encodes, both learned the hard way:
  * core/coreMode is an enum: 1 = client, 2 = server.
  * "section: screens" in the server's config file is ignored ("Screens have moved to the general
    config"). Each computer must instead be a [computer_<name>] group with name=<name> in
    Deskflow.conf, or the server fails with 'unknown computer name' and exits with code 4.

Exit codes: 0 written, 1 refused (bad name, or Deskflow running without --allow-running), 2 usage.
"""
import argparse
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

OPPOSITE = {"right": "left", "left": "right", "up": "down", "down": "up"}
# Deskflow strips leading and trailing "-", "_" and "." from computer names, so a name must start and
# end with a letter or digit, or the name it uses and the [computer_<name>] group would differ.
NAME_RE = re.compile(r"[A-Za-z0-9](?:[A-Za-z0-9._-]{0,61}[A-Za-z0-9])?")
HOST_RE = re.compile(r"[A-Za-z0-9.:-]{1,253}")


class QtIni:
    """Minimal line-preserving editor for a Qt INI file."""

    def __init__(self, text):
        self.sections = {}  # section name -> list of raw lines (without the header)
        self.order = []
        current = None
        for line in text.splitlines():
            header = re.fullmatch(r"\[(.+)\]", line.strip())
            if header:
                current = self._open(header.group(1))
            elif line.strip() or current is not None:
                # keys before any header belong to Qt's "General" group
                current = current or self._open("General")
                self.sections[current].append(line)

    def _open(self, section):
        """Start (or, for a repeated header, continue) a section; returns its name."""
        if section not in self.sections:
            self.order.append(section)
            self.sections[section] = []
        return section

    def remove(self, section):
        if section in self.sections:
            del self.sections[section]
            self.order.remove(section)

    def set(self, section, key, value):
        if section not in self.sections:
            self.order.append(section)
            self.sections[section] = []
        lines = self.sections[section]
        for i, line in enumerate(lines):
            if line.split("=", 1)[0] == key:
                lines[i] = f"{key}={value}"
                return
        while lines and not lines[-1].strip():
            lines.pop()
        lines.append(f"{key}={value}")

    def text(self):
        out = []
        for name in self.order:
            body = [l for l in self.sections[name]]
            while body and not body[-1].strip():
                body.pop()
            out.append(f"[{name}]")
            out.extend(body)
            out.append("")
        return "\n".join(out)


def backup(path):
    if path.exists():
        copy = path.with_name(f"{path.name}.bak-{time.strftime('%Y%m%d-%H%M%S')}")
        shutil.copy2(path, copy)
        print(f"backed up {path.name} to {copy}")


def deskflow_running():
    return subprocess.run(["pgrep", "-f", "Deskflow.app/Contents/MacOS/"],
                          capture_output=True).returncode == 0


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("mode", choices=["server", "client"])
    p.add_argument("--name", required=True, help="this Mac's name inside Deskflow")
    p.add_argument("--client", help="server only: the client Mac's Deskflow name")
    p.add_argument("--side", default="right", choices=sorted(OPPOSITE),
                   help="server only: where the client screen sits (default: right)")
    p.add_argument("--server", help="client only: the server's IP address or host name")
    p.add_argument("--config-dir", default=str(Path.home() / "Library" / "Deskflow"))
    p.add_argument("--allow-running", action="store_true",
                   help="write even though Deskflow is running (it may overwrite the file on quit)")
    a = p.parse_args()

    if a.mode == "server" and not a.client:
        p.error("server mode needs --client")
    if a.mode == "client" and not a.server:
        p.error("client mode needs --server")
    for n in filter(None, [a.name, a.client]):
        if not NAME_RE.fullmatch(n):
            print(f"refused: {n!r} is not a usable Deskflow name (letters, digits, . _ -;"
                  " starting and ending with a letter or digit)", file=sys.stderr)
            return 1
    if a.client and a.client == a.name:
        print("refused: --name and --client must differ", file=sys.stderr)
        return 1
    if a.server and not HOST_RE.fullmatch(a.server):
        print(f"refused: {a.server!r} is not an IP address or host name", file=sys.stderr)
        return 1
    if deskflow_running() and not a.allow_running:
        print("refused: Deskflow is running. Quit it first (kill -TERM its two processes;"
              " AppleScript quit is refused), or pass --allow-running.", file=sys.stderr)
        return 1

    cfg_dir = Path(a.config_dir).expanduser()
    cfg_dir.mkdir(parents=True, exist_ok=True)
    conf = cfg_dir / "Deskflow.conf"
    backup(conf)
    ini = QtIni(conf.read_text() if conf.exists() else "")

    ini.set("core", "coreMode", "2" if a.mode == "server" else "1")
    ini.set("core", "computerName", a.name)
    ini.set("gui", "startCoreWithGui", "true")
    ini.set("log", "toFile", "true")
    ini.set("log", "file", str(cfg_dir / "deskflow.log"))
    ini.set("log", "level", "INFO")

    if a.mode == "server":
        links = cfg_dir / "deskflow-server.conf"
        backup(links)
        links.write_text(
            "section: links\n"
            f"\t{a.name}:\n\t\t{a.side} = {a.client}\n"
            f"\t{a.client}:\n\t\t{OPPOSITE[a.side]} = {a.name}\n"
            "end\n\n"
            "section: options\n\tclipboardSharing = true\nend\n")
        ini.set("gui", "shownServerFirstStartMessage", "true")
        ini.set("server", "enableClipboard", "true")
        ini.set("server", "externalConfig", "true")
        ini.set("server", "externalConfigFile", str(links))
        # exactly the computers in this layout: a group left from an older layout would linger
        for section in [s for s in ini.order if s.startswith("computer_")]:
            ini.remove(section)
        for n in (a.name, a.client):
            ini.set(f"computer_{n}", "name", n)
        print(f"wrote {links}: {a.client} is to the {a.side} of {a.name}")
    else:
        ini.set("client", "remoteHost", a.server)

    conf.write_text(ini.text())
    print(f"wrote {conf} ({a.mode}, name {a.name})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
