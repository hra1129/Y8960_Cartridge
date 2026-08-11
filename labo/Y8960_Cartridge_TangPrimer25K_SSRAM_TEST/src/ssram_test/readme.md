# ssram_test LED Status

This document describes LED states driven by ssram_test.v.

## Important note
In top-level, LED output is inverted.
The test module drives `w_led`, and the board LED is assigned by `led = ~w_led`.
So, on board:
- `w_led` bit = 0: LED ON
- `w_led` bit = 1: LED OFF

## LED patterns in ssram_test.v (w_led)
- `0001`
State: wait for DIPSW change (test not started)

- `0011`
State: write test in progress (512KB write)

- `0111`
State: read/verify test in progress (512KB read + compare)

- `1011`
State: all tests passed (PASS)

- `1111`
State: verify failed (FAIL)
Behavior: in ST_DONE, bit3 blinks (`led[3] = ff_blink_count[23]`), bits[2:0] stay `111`

## State mapping (from ssram_test.v)
- ST_WAIT_DIP -> `0001`
- ST_WR_REQ / ST_WR_WAIT / ST_WR_NEXT -> `0011`
- ST_RD_REQ / ST_RD_WAIT_READY / ST_RD_WAIT_DATA / ST_RD_CHECK / ST_RD_NEXT -> `0111`
- PASS (after final verify) -> `1011`
- FAIL (mismatch detected) -> `1111`, then blink bit3 in ST_DONE

## UART messages
- `START`
Meaning: test start trigger accepted (DIPSW changed), write phase begins.

- `WRDONE`
Meaning: 512KB write phase completed, read/verify phase begins.

- `PASS`
Meaning: all 512KB addresses were read back and matched expected data.

- `FAIL`
Meaning: readback mismatch detected at least once during verify phase.

## UART order
Normal sequence is:
- `START` -> `WRDONE` -> `PASS`

If verification fails, sequence is:
- `START` -> `WRDONE` -> `FAIL`
