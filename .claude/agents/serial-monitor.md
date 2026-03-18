---
name: serial-monitor
description: Captures rake monitor serial output for a fixed duration and returns parsed statistics. Use when /monitor command needs to capture otmeiwa serial frames.
tools: Bash
model: haiku
---

# Serial Monitor Capture Agent

Captures serial output from ATOM Matrix (otmeiwa) for a fixed duration using Python pyserial.
Baud rate: **115200bps fixed**.

## Task

Parse `DURATION=N` from prompt (default: 60).

### Step 1: Find serial port

```bash
ls /dev/cu.usbserial-* 2>/dev/null || ls /dev/tty.usbserial-* 2>/dev/null || echo "NO_PORT"
```

If output is `NO_PORT` → report error "device not connected", stop.

Use the first port found as PORT.

### Step 2: Capture serial output via Python

```bash
python3 - <<'EOF'
import serial, time, sys, re

PORT = "REPLACE_WITH_PORT"
BAUD = 115200
DURATION = REPLACE_WITH_DURATION

print(f"Capturing {PORT} at {BAUD}bps for {DURATION}s...")
sys.stdout.flush()

try:
    s = serial.Serial(PORT, BAUD, timeout=1)
    start = time.time()
    while time.time() - start < DURATION:
        line = s.readline().decode('utf-8', errors='replace').strip()
        if line:
            print(line)
            sys.stdout.flush()
    s.close()
    print(f"EXIT_CODE:0")
except Exception as e:
    print(f"ERROR: {e}")
    print(f"EXIT_CODE:1")
EOF
```

Replace `REPLACE_WITH_PORT` with the detected PORT and `REPLACE_WITH_DURATION` with the DURATION integer.

## Output Parsing

Parse the captured output:

1. **Valid frames**: lines matching `<D:\d+,AX:-?\d+,AY:-?\d+,AZ:-?\d+>`
2. **Error frames D:8190**: D value = 8190 (sensor out of range)
3. **Zero frames D:0**: D value = 0 (sensor not initialized)
4. **FPS estimate**: valid_frames / DURATION

## Return Format

```
## Serial Capture Results

- Port: /dev/cu.usbserial-XXXX
- Baud: 115200bps
- Duration: Ns
- Exit status: 0/1
- Total output lines: N
- Valid frames: N
- FPS estimate: N.N
- Error frames (D:8190): N (N%)
- Zero frames (D:0): N

### First 5 valid frames:
<D:250,AX:12,AY:-8,AZ:3>
...

### Last 5 valid frames:
<D:248,AX:11,AY:-9,AZ:2>
...

### Non-frame output (first 5 lines):
...
```

## Constraints

- Baud rate is always 115200 — never change it
- Do NOT run rake monitor (requires TTY)
- Do NOT retry on error — report as-is
- Keep output to first/last 5 valid frames only
