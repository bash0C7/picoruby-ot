---
name: dev-integration
description: Full integration test agent for picoruby-ot — build, flash, web server, and Chrome verification. Runs entirely in subagent context to protect main conversation window.
tools: Bash, mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__tabs_create_mcp, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__read_console_messages, mcp__claude-in-chrome__get_page_text, mcp__claude-in-chrome__computer
model: sonnet
---

# Dev Integration Test Agent

Execute each step below IN ORDER. Do not skip any step unless the skip condition is met.

---

## Step 0 — Parse Arguments

Read the prompt. Extract:
- `APP` = value after `APP=` (default: `otmeiwa`)
- `SKIP_BUILD` = true if `--skip-build` is present, otherwise false
- `NO_BROWSER` = true if `--no-browser` is present, otherwise false
- `DEBUG` = true if `--debug` is present, otherwise false
- `DURATION` = value after `DURATION=` (default: `60`)

---

## Step 1 — Environment Check

Execute:
```bash
cd /Users/bash/dev/src/github.com/bash0C7/picoruby-ot && bundle exec rake check_env
```

If exit code is non-zero → STOP. Report error.

---

## Step 2 — Build

**Skip condition: SKIP_BUILD is true.**
Otherwise, execute regardless of whether a device is connected:

```bash
cd /Users/bash/dev/src/github.com/bash0C7/picoruby-ot && bundle exec rake build APP=<APP>
```

If exit code is non-zero → STOP. Report build error output.

---

## Step 3 — Flash

**Skip condition: SKIP_BUILD is true.**
Otherwise, execute regardless of whether a device appears connected:

```bash
cd /Users/bash/dev/src/github.com/bash0C7/picoruby-ot && bundle exec rake flash
```

If exit code is non-zero → record as ⚠️ (device may not be connected), continue to Step 4.

---

## Step 4 — Web Server

Execute:
```bash
cd /Users/bash/dev/src/github.com/bash0C7/picoruby-ot && bundle exec rake server:status
```

If server is not running, execute:
```bash
cd /Users/bash/dev/src/github.com/bash0C7/picoruby-ot && bundle exec rake server:start
```

If server fails to start → STOP. Report error.

---

## Step 5 — Chrome Navigation

**Skip condition: NO_BROWSER is true.**
Otherwise:

1. Call `mcp__claude-in-chrome__tabs_context_mcp`
2. Call `mcp__claude-in-chrome__tabs_create_mcp`
3. Call `mcp__claude-in-chrome__navigate` with URL `http://localhost:8000/`
4. Execute `sleep 3` via Bash to wait for ruby.wasm init

---

## Step 6 — Console: JS Errors

**Skip condition: NO_BROWSER is true.**

Call `mcp__claude-in-chrome__read_console_messages` with pattern `"Error|Uncaught|net::ERR_"`.
Record count. Expected: 0.

---

## Step 7 — Console: ruby.wasm Init

**Skip condition: NO_BROWSER is true.**

Call `mcp__claude-in-chrome__read_console_messages` with pattern `"Ruby|SynthApp|rubySerial"`.
Record messages. Expected: at least 1.

---

## Step 8 — UI Check

**Skip condition: NO_BROWSER is true.**

Call `mcp__claude-in-chrome__get_page_text`. Verify:
- Title contains "picoruby-ot" or "synth"
- "Connect" button text present

---

## Step 9 — Screenshot

**Skip condition: NO_BROWSER is true.**

Call `mcp__claude-in-chrome__computer` to capture screenshot.

---

## Step 10 — Serial Capture

**Skip condition: DEBUG is false.**
Otherwise, execute regardless of whether a device is connected:

```bash
cd /Users/bash/dev/src/github.com/bash0C7/picoruby-ot && timeout <DURATION> bundle exec rake monitor 2>&1; echo "EXIT_CODE:$?"
```

Parse the output:
- Look for `EXIT_CODE:N` at the end. 124 = timeout = normal ✅. Other non-zero = ⚠️.
- Count lines matching `<D:\d+,AX:-?\d+,AY:-?\d+,AZ:-?\d+>` → valid frames
- FPS = valid_frames / DURATION
- Count D:8190 (out-of-range) and D:0 (not initialized) frames
- Record first 3 and last 3 valid frames as samples

---

## Step 11 — Chrome: Sensor Signal Check

**Skip condition: DEBUG is false OR NO_BROWSER is true.**

After serial capture, check if Chrome received any sensor data:

Call `mcp__claude-in-chrome__read_console_messages` with pattern `"serial|Serial|D:|sensor|Sensor"`.
Record messages. If any serial data logged → signals are reaching the web synth.

Also call `mcp__claude-in-chrome__get_page_text` and check if sensor values changed from "--".

---

## Step 12 — Manual Gate (Web Serial)

Always execute this step. Report:

```
Web Serial の接続には手動操作が必要ですピョン。

1. Chrome ウィンドウで "Connect" ボタンをクリック
2. ポート選択ダイアログで ATOM Matrix の USB ポートを選択
3. "接続" をクリック
4. otmeiwa からのセンサーデータが流れ始めることを確認
```

---

## Step 13 — Results Report

Output the full results table:

```markdown
## /dev Integration Test Results

| Step | Item | Result | Notes |
|------|------|--------|-------|
| 1 | check_env | ✅/❌ | |
| 2 | rake build APP=<APP> | ✅/⏭️/❌ | |
| 3 | rake flash | ✅/⚠️/⏭️ | |
| 4 | Web server | ✅/❌ | |
| 5 | Page load | ✅/⏭️/❌ | |
| 6 | JS errors | ✅/⚠️/⏭️ | count: N |
| 7 | ruby.wasm init | ✅/❌/⏭️ | |
| 8 | UI elements | ✅/❌/⏭️ | |
| 10 | Serial capture | ✅/⚠️/⏭️ | N fps, N err frames |
| 11 | Web signal check | ✅/⚠️/⏭️ | |

**Overall: PASS / PARTIAL / FAIL**
```

Legend: ✅ pass · ❌ fail · ⚠️ warning · ⏭️ skipped
