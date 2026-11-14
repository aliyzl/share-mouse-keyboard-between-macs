# Why the pointer lagged, and what fixed it

**Kind:** report · **Date:** 2026-11-14, measurements 22:44–23:52, diagnosis 23:10–23:30 (all times UTC+03:30)
· **Status:** closed. The fix is in use, and the person confirmed the lag was gone.

## Question

Deskflow connected and every function worked, but the pointer on the client Mac lagged so badly that the setup
was unusable. Was the cause Deskflow, one of the Macs, or the network, and what removes it?

## Verdict

**The Wi-Fi path between the Macs, not Deskflow.** A direct Ethernet cable between the Macs took round trips from
**averages of 460–1,000 ms (single ones up to 2.8 s) down to 0.6 ms**, and the lag disappeared. Wi-Fi stays in use
for the internet.

At the decisive moment, the server's own Wi-Fi leg was the slow one. The client reached the router in 5 ms, while
the server needed 542 ms. The leading explanation is Bluetooth–Wi-Fi coexistence on the server's shared 2.4 GHz
radio, on top of a crowded channel. It is consistent with every measurement, but it was not proven (see *What is
uncertain*).

## Why

1. **Both Macs saw the same slow router** when the lag was first reported: 579 ms from the server and 510 ms from
   the client. Their own traffic was negligible (0.4 KB/s in, 1.1 KB/s out on the server). So the delay was in
   the air or at the router, not in either Mac's workload.
2. **Deskflow was ruled out directly.** With its core stopped, the server's latency to the router was unchanged
   (517 ms average, against 579 ms with it running).
3. **Simple power saving on the server was ruled out.** Keeping the server's radio busy with a second stream of
   10 pings a second left the pattern unchanged.
4. **The pattern points at the radio, not at congestion alone.** The server's round trips fell in a staircase of
   about 205 ms per step. That is the actual spacing of the sends (nominally 0.2 s), so the replies were held and
   delivered together about once a second. A busy channel delays packets more evenly. A radio that is away from the channel, or not listening,
   releases them in bursts.
5. **Later, only the server's leg stayed slow.** At 23:22 the client reached the router in 5 ms while the server
   needed 542 ms. Whatever was shared earlier (the channel) had eased; the server-specific part had not.
6. **The server's radio has a known competitor.** Its mouse is Bluetooth, Bluetooth LE scanning was running, and
   the Wi-Fi log showed `BT_COEX` events. On Macs, Bluetooth and 2.4 GHz Wi-Fi share one radio. The mouse is
   busiest exactly when the person is moving it to control the other Mac.

## Numbers

| Path | When | Average round trip |
| --- | --- | --- |
| client → server, Wi-Fi | 22:56, before Deskflow | 19.7 ms |
| client → server, Wi-Fi | 23:16, 100 pings at 20 ms | 370 ms (max 920) |
| server → client, Wi-Fi | 23:13, lag reported | 998 ms (max 2,120) |
| server → router, Wi-Fi | 23:13 | 579 ms |
| server → router, Deskflow stopped | 23:18 | 517 ms |
| client → router, Wi-Fi | 23:22 | 5 ms |
| server → router, Wi-Fi | 23:22 | 542 ms |
| **server ↔ client, Ethernet cable** | **23:29** | **0.6 ms** |

Every measurement, with the radio environment, is in [evidence/measurements.md](evidence/measurements.md).

## What is uncertain

- **Bluetooth coexistence is the leading explanation, not a proven one.** Proving it would need the same
  measurement with Bluetooth off, which disconnects the mouse in use. That test was not worth the disruption once
  the cable had solved the problem.
- **The channel's own load was not measured.** Airtime use by the two stronger neighbouring networks on
  channel 9 could not be seen from either Mac.
- **The router was not examined.** It is a 2.4 GHz-only LTE gateway. Its admin page, which shows other devices'
  traffic, was not opened.

## What would have been tried next without a cable

These were not tried, so they are untested:

1. moving the router off channel 9 (networks sat on channels 1, 2, 3, 6, 9 and 10; none on 11–13, though 9 and 10 overlap them);
2. connecting only the server to the router by Ethernet, since its leg was the slow one;
3. a 5 GHz network, which would separate Wi-Fi from Bluetooth entirely; this router could not offer one.

## Method

Pings ran at 0.1–0.25 s intervals. Wi-Fi details were taken from `system_profiler SPAirPortDataType` **after**
the pings, because a scan takes the radio off its channel. Traffic came from `netstat -ibn` deltas over 5 s, and
the Bluetooth activity from `log show` for `airportd` and `bluetoothd`. The client's CPU was checked (`deskflow-core`
at 0.3 %); the server's was not measured, but stopping its Deskflow core did not change the latency. The procedure is packaged as
[`measure-latency.sh`](../../skills/deskflow-two-macs/scripts/measure-latency.sh).
