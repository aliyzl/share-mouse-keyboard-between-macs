#!/usr/bin/env bash
# Read-only status of Deskflow on this Mac: install, settings, processes, connection, recent log.
# Usage: check-deskflow.sh [--share]
#   --share  mask what identifies you (home path, IP addresses, fingerprints, computer names) so the
#            output can be pasted into a public issue. Without it, the output is for your eyes only.
# Exit codes: 0 = core running (and, on a client, connected); 1 = something to fix (printed as FIX lines).
set -uo pipefail

if [[ "${1:-}" == "--share" ]]; then
  conf="$HOME/Library/Deskflow/Deskflow.conf"
  names="$(awk -F= '/^(computerName|name|remoteHost)=/{print $2}' "$conf" 2>/dev/null | sort -u)"
  "$0" | /usr/bin/python3 -I -c '
import re, sys
home, names = sys.argv[1], [n for n in sys.argv[2].split("\n") if n]
text = sys.stdin.read().replace(home, "~")
text = re.sub(r"\b[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){15,}\b", "<fingerprint>", text)
text = re.sub(r"\b\d{1,3}(\.\d{1,3}){3}\b", "<ip>", text)
for i, n in enumerate(sorted(names, key=len, reverse=True), 1):
    text = re.sub(re.escape(n), f"<name{i}>", text)
sys.stdout.write(text)
' "$HOME" "$names"
  exit "${PIPESTATUS[0]}"
fi

APP="/Applications/Deskflow.app"
DIR="$HOME/Library/Deskflow"
CONF="$DIR/Deskflow.conf"
problems=0
ok()  { printf '  ok   %s\n' "$*"; }
fix() { printf '  FIX  %s\n' "$*"; problems=$((problems + 1)); }
ini() { awk -F= -v s="[$1]" -v k="$2" '$0==s{f=1;next} /^\[/{f=0} f&&$1==k{print substr($0,length(k)+2)}' "$CONF" 2>/dev/null; }

echo "Install"
if [[ -d "$APP" ]]; then
  ok "$("$APP/Contents/MacOS/deskflow-core" --version 2>/dev/null | head -1)"
  team="$(codesign -dv "$APP" 2>&1 | awk -F= '/^TeamIdentifier=/{print $2}')"
  if [[ "$team" == "5QCJCX8C37" ]]; then ok "signed by team $team"; else fix "unexpected signing team '$team'"; fi
else
  fix "$APP is missing: run install-deskflow.sh"
fi

echo "Settings ($CONF)"
mode="$(ini core coreMode)"; name="$(ini core computerName)"
case "$mode" in
  2) ok "mode server, name '$name'" ;;
  1) ok "mode client, name '$name', server '$(ini client remoteHost)'" ;;
  *) fix "core/coreMode is '${mode:-unset}': run write-deskflow-config.py" ;;
esac
if [[ "$mode" == 2 ]]; then
  links="$(ini server externalConfigFile)"
  if [[ -r "$links" ]]; then ok "layout file $links"; else fix "layout file '${links:-unset}' not readable"; fi
  grep -q '^section: screens' "$links" 2>/dev/null && fix "layout file has 'section: screens', which 1.27 ignores"
  # every computer named in the links section needs its own [computer_<name>] group
  for n in $(awk -F= '/^section: links/{f=1;next} /^end/{f=0} f&&/=/{gsub(/[ \t]/,"",$2); print $2}' "$links" 2>/dev/null | sort -u) "$name"; do
    grep -q "^\[computer_$n\]" "$CONF" || fix "no [computer_$n] group in Deskflow.conf ('unknown computer name')"
  done
fi

echo "Processes"
if pgrep -f "$APP/Contents/MacOS/Deskflow" >/dev/null; then ok "GUI running"; else fix "GUI not running: open -a Deskflow"; fi
core="$(pgrep -lf "$APP/Contents/MacOS/deskflow-core" | head -1)"
if [[ -n "$core" ]]; then ok "core running: ${core#* }"; else fix "core not running (see the log below)"; fi

echo "Network"
if [[ "$mode" == 2 ]]; then
  if lsof -nP -iTCP:24800 -sTCP:LISTEN >/dev/null 2>&1; then ok "listening on TCP 24800"; else fix "nothing listens on TCP 24800"; fi
fi
conns="$(lsof -nP -iTCP:24800 -sTCP:ESTABLISHED 2>/dev/null | awk 'NR>1{print $9}')"
if [[ -n "$conns" ]]; then
  while read -r c; do
    peer="${c#*->}"; peer="${peer%:*}"
    iface="$(route -n get "$peer" 2>/dev/null | awk '/interface:/{print $2}')"
    ok "connected $c (via $iface)"
  done <<< "$conns"
elif [[ "$mode" == 1 ]] && lsof -nP -iTCP:24800 -sTCP:SYN_SENT >/dev/null 2>&1; then
  fix "stuck in SYN_SENT: allow Deskflow in Privacy & Security -> Local Network (macOS 15+)"
elif [[ "$mode" == 1 ]]; then
  fix "not connected: check the server, then Local Network permission for Deskflow"
else
  echo "  --   no client connected right now"
fi

echo "TLS"
pem="$DIR/tls/deskflow.pem"
if [[ -r "$pem" ]]; then ok "own certificate $(openssl x509 -in "$pem" -noout -fingerprint -sha256 | cut -d= -f2)"
else echo "  --   no certificate yet (Deskflow makes one on first start)"; fi
for f in trusted-servers trusted-clients; do
  [[ -r "$DIR/tls/$f" ]] && ok "$f: $(grep -c . "$DIR/tls/$f") entr(y/ies)"
done

log="$(ini log file)"
if [[ "$(ini log toFile)" == "true" && -r "$log" ]]; then
  echo "Last log lines ($log)"
  tail -8 "$log" | sed 's/^/  /'
fi

echo
if [[ $problems -eq 0 ]]; then echo "VERDICT: OK"; exit 0; else echo "VERDICT: $problems thing(s) to fix"; exit 1; fi
