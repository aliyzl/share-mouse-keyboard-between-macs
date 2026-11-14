# Measurements, 2026-11-14 (Tehran, +0330)

Raw figures from both sessions, in time order. **S** is the server, the iMac (Apple Silicon, the keyboard
and Bluetooth mouse). **C** is the client, the MacBook Pro (Intel). **R** is the home router. The Wi-Fi LAN
addresses are replaced by these letters.

All pings are ICMP from macOS `ping`, at the interval shown. "Series" lines list each round trip in ms, in send
order.

## Before Deskflow was installed

| Time | From → to | Packets, interval | min / avg / max (ms) | Note |
| --- | --- | --- | --- | --- |
| 22:49 | S → C | 2 | 37.9 / 58.6 / 79.4 | first contact |
| 22:52 | S → C | 20, 0.2 s | 4.0 / 111.8 / 377.2 (sd 108.7) | |
| 22:56 | C → S | 20, 0.2 s | 3.6 / 19.7 / 83 (sd 24) | measured on C; no loss |

## After Deskflow was working, when the lag was reported

| Time | From → to | Packets, interval | min / avg / max (ms) | Note |
| --- | --- | --- | --- | --- |
| 23:13 | S → R | 50, 0.1 s | 68.8 / 579.0 / 1134.7 (sd 298.2) | |
| 23:13 | S → C | 50, 0.1 s | 76.0 / 998.1 / 2120.5 (sd 598.1) | |
| 23:16 | C → R | 50, 0.1 s | 19 / 510 / 1000 | measured on C, without a concurrent scan |
| 23:16 | C → S | 50, 0.1 s | — / 810 / 1940 | measured on C |
| 23:22 | C → R | 50 | — / 5 / 14 | measured on C |
| 23:22 | C → S | 50 | — / 460 / 927 | measured on C |
| 23:22 | S → R | 40, 0.2 s | 51.8 / 542.1 / 1220.4 (sd 314.8) | |

S's own traffic at 23:14, sampled over 5 s on its Wi-Fi interface: **0.4 KB/s in, 1.1 KB/s out**. Deskflow had sent
about 40 KB in total since it started. C's traffic was 10–20 KB/s, and `deskflow-core` used 0.3 % CPU on C.

### Series: S → R at 23:14, 100 pings at 0.2 s

```text
962 757 552 352 150 979 774 570 365 162 999 798 597 392 187 937 732 527 326 122 942 741 535 330 129
970 765 561 357 155 1004 804 601 399 193 912 711 498 294 92 897 692 486 281 78 885 479 274 70 875
671 466 261 55 861 660 455 255 50 868 663 458 252 51 841 638 433 228 23 829 624 419 213 1070 865
660 455 250 1079 876 671 466 264 992 786 581 376 171 1005 799 597 394 188 1024 820 615 410 205 1052
```

Each run of five values falls by about 205 ms, which is the send interval. So all five replies arrived at the
same moment, about once a second.

### Series: S → C at 23:15, 50 pings at 0.2 s

```text
1975 2826 2625 2423 2218 2013 1807 1602 1399 1194 989 788 583 377 1117 912 711 506 300 1111 905 705 499 294
1138 933 728 523 318 113 1870 1664 1459 1254 1049 844 641 439 234 1039 1845 1641 1436 1231 1025 820 615
1420 1215 1009
```

## Tests that changed one thing

| Time | Change | Result (S → R, 40 pings at 0.25 s) | Reading |
| --- | --- | --- | --- |
| 23:16 | a second ping stream at 10/s kept S's radio busy | `834 580 325 70 958 703 448 196 621 ...` (the same staircase) | not S's power saving |
| 23:16 | the same without the extra stream | `838 583 334 79 890 635 380 126 896 ...` | baseline |
| 23:18 | `deskflow-core` stopped on S | 34.3 / 516.9 / 1122.1 (60 pings at 0.25 s) | not Deskflow |

## Radio environment (taken after the pings, never during)

| | S | C |
| --- | --- | --- |
| PHY, channel | 802.11n, channel 9, 2.4 GHz, 20 MHz | 802.11n, channel 9, 2.4 GHz, 20 MHz |
| signal / noise | −51 / −102 dBm | −54 / −90 dBm |
| MCS, transmit rate | 13, 115 Mb/s | 13, 130 Mb/s |
| Bluetooth | mouse on Bluetooth; Bluetooth LE scanning at 30 ms per 300 ms; `BT_COEX` events in the Wi-Fi log | — |
| AWDL | `awdl0` active, 0 bytes moved in 5 s | `awdl0` active |

Neighbouring networks seen from S: two on channel 9 at −43 and −45 dBm (stronger than the home router), two on
channel 6, one on 10, two on 1 (one of them 40 MHz wide), and one each on 2 and 3. No 5 GHz network was visible,
and the home router is a 2.4 GHz-only LTE gateway.

## After the cable

| Time | From → to | Packets, interval | min / avg / max (ms) | Path |
| --- | --- | --- | --- | --- |
| 23:29 | C → S | 40 | 0.40 / 0.60 / 0.94 | direct Gigabit Ethernet |
| 23:30 | S → C | 20, 0.2 s | 0.378 / 0.617 / 0.779 | direct Gigabit Ethernet |
| 23:52 | S → C and S → R | 20 each, 0.2 s | cable 0.617 avg; router 545.2 avg | the Wi-Fi was still slow; the cable did not care |

The person confirmed that the lag was gone.
