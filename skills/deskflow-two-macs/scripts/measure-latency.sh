#!/usr/bin/env bash
# Measure round-trip latency to the other Mac (and to the router, for comparison) and show the
# per-packet pattern, which is what tells a busy network from a radio that holds packets back.
# Usage: measure-latency.sh <other-mac-ip> [count]      (default count 50, one ping every 0.2 s)
# Exit codes: 0 = average under 20 ms (usable for a pointer); 1 = 20 ms or slower; 2 = usage or no replies.
set -uo pipefail

host="${1:-}"; count="${2:-50}"
[[ -n "$host" ]] || { sed -n '2,5p' "$0"; exit 2; }

series() {  # ping and print every round-trip time on one line, then the summary line
  ping -c "$count" -i 0.2 "$1" 2>/dev/null \
    | awk -F'time=' '/time=/{split($2,a," "); printf (a[1] < 10 ? "%.1f " : "%d "), a[1]} /packet loss/{loss=$0} /round-trip/{print ""; print "  " loss; print "  " $0}'
}

iface="$(route -n get "$host" 2>/dev/null | awk '/interface:/{print $2}')"
echo "Path to $host leaves through ${iface:-unknown}"
echo "Per-packet RTT to $host, ms:"
out="$(series "$host")"; echo "  $out"
avg="$(awk -F'[/ ]+' '/round-trip/{print $(NF-3)}' <<< "$out")"
[[ -n "$avg" ]] || { echo "no replies from $host"; exit 2; }

gw="$(route -n get default 2>/dev/null | awk '/gateway:/{print $2}')"
lan_gw="$(netstat -rn -f inet 2>/dev/null | awk -v i="$iface" '$1=="default" && $NF==i {print $2; exit}')"
gw="${lan_gw:-$gw}"
if [[ -n "$gw" && "$gw" != "$host" && "$gw" =~ ^[0-9.]+$ ]]; then
  echo "Per-packet RTT to the router $gw, ms:"
  echo "  $(series "$gw")"
fi

cat <<'EOF'

How to read it:
  * A cable between the Macs gives under 1 ms. Good Wi-Fi gives under 5 ms. Above about 20 ms
    the pointer on the client feels late; above 100 ms it is unusable.
  * A falling staircase (900 700 500 300 100 900 ...) means frames are held and released
    together about once a second: the radio is away from the channel or asleep, not merely busy.
  * If the router is as slow as the other Mac, the Wi-Fi itself is the problem, not Deskflow.
  * Run Wi-Fi scans (system_profiler SPAirPortDataType) only after this, never during: a scan
    takes the radio off its channel and spoils the numbers.
EOF

if awk -v a="$avg" 'BEGIN{exit !(a < 20)}'; then exit 0; else exit 1; fi
