# Robot wire protocol v1

UART: 9600 baud, 8 data bits, no parity, 1 stop bit, no flow control.
HC-05 must be in slave **data mode**, with UART configured to 9600 (AT mode
baud rates and defaults vary). ASCII frames contain exactly one uppercase byte
followed by LF (`0x0A`). Do not send CRLF to the firmware.

| Frame | Left PWM | Right PWM | Effect |
| --- | ---: | ---: | --- |
| `F\n` | 160 | 160 | Forward |
| `B\n` | -160 | -160 | Backward |
| `L\n` | -160 | 160 | Pivot left |
| `R\n` | 160 | -160 | Pivot right |
| `S\n` | 0 | 0 | Coast, STBY low |

Signs describe desired wheel direction after correct motor polarity wiring.
PWM is fixed at 160/255, not a measured speed. The firmware disables STBY before
changing direction pins. Stop disables both channels; it does not hold position.

- Boot: stopped, response `READY S\r\n` (may be sent before a phone connects).
- Valid complete frame: `OK F\r\n`, etc. This confirms requested outputs only.
- Unknown byte, extra byte, empty line or stale partial frame: stop and `ERR\r\n`.
  After an invalid byte, discard through the next LF before accepting a new frame.
- A partial frame expires at **100 ms**; it cannot be completed later to restart
  motion. An LF that completes a frame at that boundary also rejects it.
- Motion expires at **500 ms** since the last valid complete command: stop and
  `TIMEOUT\r\n` once. Unsigned elapsed arithmetic handles `millis()` rollover.
- Fresh valid frames can resume motion after an error/timeout. There is no
  authentication, sequence numbering, replay protection or motion telemetry.

The app sends S first and enables movement only after OK S. While connected it
repeats the desired frame every 100 ms; release requests S. It allows one write
at a time and coalesces changes, rather than building a movement queue. A write
exceeding 300 ms or no recognized firmware acknowledgement for 700 ms closes the
link. ERR/TIMEOUT also close the link and require explicit reconnection. A stop
is best effort before intentional disconnect; if a write is blocked the app
closes without queueing more frames. The independent firmware watchdog is the
final stop boundary. Wireless buffering can delay delivery; this is not a
safety-rated control system.

Examples (no hardware required):

The app's **Start demo** action uses the same client controller and reply parser
with an in-memory transport. It acknowledges movement/stop frames without
opening Bluetooth, requesting permissions or sending UART bytes. Demo never
replaces an active or pending real connection. Exit/background resets it to
stopped and discards feedback before a real connection can start. This is a UI
and protocol-feedback demonstration, not a simulation of firmware timing or
motor physics.

```sh
./scripts/test-firmware.sh
cd app
flutter test
```

For manual UART inspection, use a Bluetooth SPP terminal on Android, line ending
LF only; send `S` first, then `F` briefly and observe timeout. This is an optional
hardware acceptance procedure, not a test performed by this repository's CI.
