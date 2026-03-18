---
name: monitor
description: Serial monitor + Chrome integration — start web server, connect Chrome, capture rake monitor output for N seconds
---

# /monitor — Serial + Chrome Monitor Command

Starts web server, connects Chrome, captures serial output for a fixed duration, and reports results.

## Usage

```
/monitor [DURATION=60] [--skip-browser]
```

- `DURATION=N` : capture duration in seconds (default: 60)
- `--skip-browser` : skip Chrome verification

## Execution Phases

### Phase 0 — Parse Arguments

Parse from `$ARGUMENTS`:
- Extract `DURATION=N` (default: 60)
- Detect `--skip-browser` flag

Report parsed args to user before proceeding.

### Phase 1 — Web Server

Check and start server if needed:

```bash
rake server:status
# If not running:
rake server:start
```

Use Bash tool directly. If server fails to start → **STOP** and report error.

### Phase 2 — Chrome Navigation (unless --skip-browser)

Use `mcp__claude-in-chrome__tabs_context_mcp` to check current tabs.
Create a new tab with `mcp__claude-in-chrome__tabs_create_mcp`.
Navigate to `http://localhost:8000/` with `mcp__claude-in-chrome__navigate`.

Wait ~3 seconds for ruby.wasm to initialize.

Verify initialization with `mcp__claude-in-chrome__read_console_messages`:
```
pattern: "Ruby|SynthApp|rubySerial"
```

Record result (initialized / not found).

### Phase 3 — Serial Capture

Delegate to **serial-monitor subagent** with:

```
DURATION=<N>
Run: timeout <N> rake monitor 2>&1
Capture all output.
Return:
- first 20 lines and last 20 lines of raw output
- total_frames (count of lines matching <D:...)
- fps_estimate (total_frames / N)
- error_frames (lines with D:8190 or D:0)
- exit_status (124 = timeout = normal, 0 = normal, other = error)
```

Exit status 124 (timeout) is **normal** — report as success.
Other non-zero exit status → report warning, continue to Phase 5.

### Phase 4 — Serial Output Analysis

From subagent results, analyze:

| Item | Expected |
|------|----------|
| Frame rate | ~20 fps |
| D:8190 ratio | < 5% (out-of-range sensor) |
| D:0 ratio | 0% (sensor not initialized) |
| AX/AY/AZ range | reasonable values |

Flag anomalies as warnings.

### Phase 5 — Chrome Console Check (unless --skip-browser)

Use `mcp__claude-in-chrome__read_console_messages`:
```
pattern: "Error|Uncaught|net::ERR_"
```

Record any matches. Expected: none.

### Phase 6 — Results Report

Output summary:

```markdown
## /monitor Results (DURATION=Ns)

### Serial Output

| Item | Value | Status |
|------|-------|--------|
| Total frames | N | ✅/⚠️ |
| FPS estimate | N.N | ✅/⚠️ |
| Error frames (D:8190) | N (N%) | ✅/⚠️ |
| Zero frames (D:0) | N | ✅/⚠️ |
| Exit status | 124 (timeout) | ✅ |

**Sample output (first 5 frames):**
```
<D:250,AX:12,AY:-8,AZ:3>
...
```

### Chrome Console

| Item | Result |
|------|--------|
| ruby.wasm init | ✅/❌ |
| JS errors | ✅ none / ⚠️ N errors |

### Overall: PASS / PARTIAL / FAIL
```

Legend: ✅ pass · ❌ fail · ⚠️ warning
