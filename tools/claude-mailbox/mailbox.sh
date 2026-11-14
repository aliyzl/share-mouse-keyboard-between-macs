#!/usr/bin/env bash
# Client for mailbox.py. Needs MAILBOX_URL (e.g. http://192.168.77.1:8765) and MAILBOX_TOKEN.
# Usage: mailbox.sh send <from-name> <<'EOF' ... EOF     post stdin as one message
#        mailbox.sh read [since-id]                      print messages after an id (default 0)
#        mailbox.sh watch <my-name> [since-id]           print each new message from anyone else, forever
set -euo pipefail
: "${MAILBOX_URL:?set MAILBOX_URL}" "${MAILBOX_TOKEN:?set MAILBOX_TOKEN}"

show() {  # JSON list on stdin -> readable blocks; $1 = name to skip (optional)
  /usr/bin/python3 -I -c '
import json, sys
skip = sys.argv[1] if len(sys.argv) > 1 else None
for m in json.load(sys.stdin):
    if m["from"] != skip:
        print("[#%s %s %s]\n%s\n" % (m["id"], m["from"], m["ts"], m["text"].rstrip("\n")), flush=True)
' "$@"
}

case "${1:-}" in
  send)
    from="${2:?send needs a sender name}"
    curl -fsS -X POST -H "X-Token: $MAILBOX_TOKEN" --data-binary @- "$MAILBOX_URL/msg?from=$from"; echo ;;
  read)
    out="$(curl -fsS -H "X-Token: $MAILBOX_TOKEN" "$MAILBOX_URL/msgs?since=${2:-0}")" || exit 1
    show <<< "$out" ;;
  watch)
    me="${2:?watch needs your own name}"; last="${3:-0}"
    while true; do
      batch="$(curl -fsS -m 5 -H "X-Token: $MAILBOX_TOKEN" "$MAILBOX_URL/msgs?since=$last" || echo '[]')"
      show "$me" <<< "$batch"
      last="$(/usr/bin/python3 -I -c 'import json,sys; m=json.load(sys.stdin); print(m[-1]["id"] if m else sys.argv[1])' "$last" <<< "$batch")"
      sleep 2
    done ;;
  *) sed -n '2,5p' "$0"; exit 2 ;;
esac
