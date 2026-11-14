# A direct cable between the two Macs

**Kind:** reference · **Verified:** 2026-11-14 with direct Gigabit Ethernet (the client through a USB-C adapter):
0.6 ms average round trip, down from 500–2,800 ms over Wi-Fi. · Thunderbolt Bridge follows the same steps
but was not measured here.

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

```bash
networksetup -listallhardwareports            # e.g. "Hardware Port: USB 10/100/1000 LAN  Device: en6"
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
sudo networksetup -setmanual "<server service name>" 192.168.77.1 255.255.255.0
# client
sudo networksetup -setmanual "<client service name>" 192.168.77.2 255.255.255.0
```

Leave the router and DNS empty. That way the cable never becomes the default route, and the internet keeps
using Wi-Fi. Without manual addresses, both ends fall back to self-assigned `169.254.x.x` addresses. Those work in
principle, but they change and are ambiguous when another interface also uses link-local addresses.

**VPNs:** a VPN in full-tunnel mode usually installs routes such as `0.0.0.0/1` and `128.0.0.0/1`. The cable's
`/24` is more specific, so it wins. Check it:

```bash
route -n get 192.168.77.2 | grep interface    # on the server: must name the cable's interface, e.g. en0
```

## 4. Point the client at the server's cable address

The server listens on every interface (`*:24800`), so nothing changes there. On the client, quit Deskflow, then:

```bash
pkill -TERM -f /Applications/Deskflow.app/Contents/MacOS/deskflow-core
pkill -TERM -f /Applications/Deskflow.app/Contents/MacOS/Deskflow
python3 skills/deskflow-two-macs/scripts/write-deskflow-config.py client --name macbook --server 192.168.77.1
open -a Deskflow
```

The TLS trust carries over, because it belongs to the certificate, not the address.

## 5. Check

```bash
bash skills/deskflow-two-macs/scripts/measure-latency.sh 192.168.77.2   # from the server: expect under 1 ms
bash skills/deskflow-two-macs/scripts/check-deskflow.sh                 # "connected ... (via en0)": the cable
```

## Undo

```bash
sudo networksetup -setdhcp "<service name>"    # or restore the configuration you noted in step 2
```

Then point the client back at the server's Wi-Fi address with `write-deskflow-config.py client ...`.
