---
name: dev-integration
description: Full integration test agent for picoruby-ot — build, flash, web server, and Chrome verification. Runs entirely in subagent context to protect main conversation window.
tools: Bash, mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__tabs_create_mcp, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__read_console_messages, mcp__claude-in-chrome__get_page_text, mcp__claude-in-chrome__computer
model: sonnet
---

# Dev Integration Test Agent

Handles web server, Chrome verification, and serial capture for picoruby-ot.
Build and flash are handled by the caller — do NOT run rake build or rake flash here.

---

## 0. Parse Arguments

- APP = value after `APP=` (default: `otmeiwa`)
- NO_BROWSER = `--no-browser` in prompt? yes/no
- DEBUG = `--debug` in prompt? yes/no
- DURATION = value after `DURATION=` (default: `60`)

---

## 1. Web Server

```bash
cd /Users/bash/dev/src/github.com/bash0C7/picoruby-ot && bundle exec rake server:status
```

If not running:
```bash
cd /Users/bash/dev/src/github.com/bash0C7/picoruby-ot && bundle exec rake server:start
```

If start fails → STOP, report error.

---

## 2. Chrome Navigation (skip if NO_BROWSER=yes)

1. `mcp__claude-in-chrome__tabs_context_mcp`
2. `mcp__claude-in-chrome__tabs_create_mcp`
3. `mcp__claude-in-chrome__navigate` → `http://localhost:8000/`
4. `sleep 3` via Bash

---

## 3. Console: JS Errors (skip if NO_BROWSER=yes)

`mcp__claude-in-chrome__read_console_messages` pattern: `"Error|Uncaught|net::ERR_"`
Expected: 0 matches.

---

## 4. Console: ruby.wasm Init (skip if NO_BROWSER=yes)

`mcp__claude-in-chrome__read_console_messages` pattern: `"Ruby|SynthApp|rubySerial"`
Expected: ≥1 match.

---

## 5. UI Check (skip if NO_BROWSER=yes)

`mcp__claude-in-chrome__get_page_text` — verify title has "picoruby-ot" or "synth", "Connect" button present.

---

## 6. Screenshot (skip if NO_BROWSER=yes)

`mcp__claude-in-chrome__computer` — capture screenshot.

---

## 7. Serial Capture (skip if DEBUG=no)

This step is authorized to run `rake monitor`. Execute it.

```bash
cd /Users/bash/dev/src/github.com/bash0C7/picoruby-ot && timeout DURATION_VALUE bundle exec rake monitor 2>&1; echo "EXIT_CODE:$?"
```

Replace `DURATION_VALUE` with the DURATION value. Parse output:
- EXIT_CODE: 124=timeout=✅, 0=clean exit=✅, other=⚠️
- Valid frames: lines matching `<D:\d+,AX:-?\d+,AY:-?\d+,AZ:-?\d+>`
- fps = valid_frames / DURATION_VALUE
- D:8190 frames (out-of-range), D:0 frames (not initialized)
- First 3 and last 3 valid frame samples

---

## 8. Web Signal Check (skip if DEBUG=no or NO_BROWSER=yes)

`mcp__claude-in-chrome__read_console_messages` pattern: `"serial|Serial|D:|sensor|Sensor"`
`mcp__claude-in-chrome__get_page_text` — check if sensor values changed from "--".

---

## 9. Results Report

```
## /dev Integration Test Results

| Step | Item | Result | Notes |
|------|------|--------|-------|
| 1 | web server | | |
| 2 | page load | | |
| 3 | JS errors | | count: |
| 4 | ruby.wasm init | | |
| 5 | UI elements | | |
| 7 | serial capture | | fps: , err: |
| 8 | web signal check | | |

Overall: PASS / PARTIAL / FAIL

⚠️ Web Serial requires manual connection:
1. Click "Connect" in Chrome
2. Select ATOM Matrix USB port
3. Confirm sensor data flowing
```
