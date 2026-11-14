# A direct cable between the two Macs

**Kind:** reference · **Verified:** 2026-11-14 with direct Gigabit Ethernet (the client through a USB 3 Gigabit
adapter): 0.6 ms average round trip, down from averages of 460–1,000 ms over Wi-Fi. · Thunderbolt Bridge follows the
same steps, but it was not tested here because no Thunderbolt cable was at hand. `<skill>` is this skill's folder:
`skills/deskflow-two-macs` in a clone of the repository.

Deskflow sends every pointer movement from the server to the client. A cable takes Wi-Fi out of that path, so the
pointer keeps up whatever the Wi-Fi is doing. Each Mac keeps using Wi-Fi for the internet, because the cable gets
an address without a router, and so no default route.

## 1. Pick the cable

| Option | What you need | How to tell it works |
| --- | --- | --- |
| **Ethernet** | an Ethernet port on each Mac, or a USB-C Gigabit adapter. Any Ethernet cable works, since modern ports cross over automatically | `ifconfig <if>` shows `status: active` and `media: autoselect (1000baseT <full-duplex>)` |
| **Thunderbolt Bridge** | a **Thunderbolt 3/4 or USB4** cable (⚡ or "40" on the plug) between Thunderbolt ports | `system_profiler SPThunderboltDataType` shows the other Mac; `ifconfig bridge0` shows `status: active` |

A USB-C charging cable carries no data between two Macs. Both show "No device connected", because two USB hosts
cannot talk over plain USB.

## 2. Find the interface and its network service

In the original setup the server used its built-in port (`en0`, service "Ethernet") and the client used a USB
adapter (`en6`, service "AX88179A"). Yours will differ:

```bash
networksetup -listallnetworkservices          # service names, e.g. "Ethernet", "AX88179A", "Thunderbolt Bridge"
networksetup -listallhardwareports            # which device each one is, e.g. "Device: en6"
ifconfig en6 | grep -E 'status|media|inet '   # after plugging in: status active
networksetup -getinfo "<service name>"        # what is configured on it now
```

**Look before you assign.** If the service already has a manual address from earlier use, either reuse its
subnet for the other end or ask before replacing it. The original server's Ethernet service already had one.

## 3. Give each end a fixed address

Use a private `/24` that nothing else on either Mac uses: not the home LAN, not a VPN's range. `192.168.77.0/24`
is used here as an example.

```bash
# server
networksetup -setmanual "<server service name>" 192.168.77.1 255.255.255.0
# client
networksetup -setmanual "<client service name>" 192.168.77.2 255.255.255.0
```

On an administrator account this needed no `sudo` and no password, and the address survived a restart. On a
standard account, prefix `sudo`. If a password is asked for in a Claude Code session, the person has to type the
command themselves. You can also do it by hand: System Settings → Network → the adapter → Details → TCP/IP →
Configure IPv4: Manually.

Leave the router and DNS empty. That way the cable never becomes the default route, and the internet keeps using
Wi-Fi. Without manual addresses, both ends fall back to self-assigned `169.254.x.x` addresses. Do not rely on those:
on the original client the `169.254/16` route was bound to Wi-Fi, and the VPN's tunnel used a `169.254` address
too. The two ends' masks need not match. The original server kept an older `/16` on its port, the client used a
`/24`, and the link worked.

**VPNs:** a VPN in full-tunnel mode usually installs routes such as `0.0.0.0/1` and `128.0.0.0/1`. The cable's
`/24` is more specific, so it wins. Check it:

```bash
route -n get 192.168.77.2 | grep interface    # on the server: must name the cable's interface, e.g. en0
```

A VPN that blocks local traffic in its firewall, rather than through routes, would pass this check and still drop
the packets. If `ping` fails while the route is right, look for the VPN's "allow LAN" or "local network sharing"
setting.

## 4. Point the client at the server's cable address

The server listens on every interface (`*:24800`), so nothing changes there. On the client, quit Deskflow, then:

```bash
pkill -TERM -f /Applications/Deskflow.app/Contents/MacOS/Deskflow
pkill -TERM -f /Applications/Deskflow.app/Contents/MacOS/deskflow-core
pgrep -lf /Applications/Deskflow.app || echo "Deskflow stopped"
<skill>/scripts/write-deskflow-config.py client --name macbook --server 192.168.77.1
open -a Deskflow
```

The TLS trust carries over, because it belongs to the certificate, not the address.

## 5. Check

```bash
<skill>/scripts/measure-latency.sh 192.168.77.2   # from the server: expect under 1 ms
<skill>/scripts/check-deskflow.sh                 # on the server "connected ... (via en0)", on the client
                                                  # "(via en6)": each names its own cable interface
```

## Undo

```bash
networksetup -setdhcp "<service name>"    # or restore the configuration you noted in step 2
```

Then point the client back at the server's Wi-Fi address with `write-deskflow-config.py client ...`.
