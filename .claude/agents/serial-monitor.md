---
name: serial-monitor
description: Captures rake monitor serial output for a fixed duration and returns parsed statistics. Use when /monitor command needs to capture otmeiwa serial frames.
tools: Bash
model: haiku
---

# Serial Monitor Capture Agent

Captures `bundle exec rake monitor` output for a fixed duration and returns parsed results.

## Task

You will receive a task with `DURATION=N` specified.

Run the following command via Bash tool:

```bash
cd /Users/bash/dev/src/github.com/bash0C7/picoruby-ot && timeout <DURATION> bundle exec rake monitor 2>&1
```

Replace `<DURATION>` with the value provided.

## Exit Status Handling

- Exit status **124** = timeout expired = **normal** (expected)
- Exit status **0** = monitor exited cleanly = normal
- Any other non-zero = error (device not connected, build issue, etc.)

## Output Parsing

After capturing, parse the output:

1. **Valid frames**: lines matching pattern `<D:\d+,AX:-?\d+,AY:-?\d+,AZ:-?\d+>`
2. **Error frames D:8190**: valid frames where D value is 8190 (out-of-range)
3. **Zero frames D:0**: valid frames where D value is 0 (sensor not initialized)
4. **FPS estimate**: total_valid_frames / DURATION

## Return Format

Return a structured report with:

```
## Serial Capture Results

- Duration: Ns
- Exit status: N (124=timeout=normal)
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

### Non-frame output (errors/warnings):
(any lines that don't match the frame pattern — first 10 lines)
```

## Constraints

- Do NOT run any other commands
- Do NOT modify any files
- Do NOT retry if rake monitor fails with non-124 exit status — report the error as-is
- Keep raw output excerpt to first/last 5 valid frames only (protect context window)
