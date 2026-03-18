---
name: dev
description: Integration test command — build, flash, start web server, and verify Chrome synth
---

# /dev — Integration Test Command

Full integration test: build → flash → web server → Chrome verification.

## Usage

```
/dev [APP=otmeiwa] [--skip-build] [--no-browser]
```

- `APP=` : firmware name (default: `otmeiwa`)
- `--skip-build` : skip build+flash (web verification only)
- `--no-browser` : skip browser automation

## Execution Phases

### Phase 0 — Parse Arguments

Parse from `$ARGUMENTS`:
- Extract `APP=xxx` (default: `otmeiwa`)
- Detect `--skip-build` flag
- Detect `--no-browser` flag

Report parsed args to user before proceeding.

### Phase 1 — Environment Check

Run `rake check_env` via Bash tool.

If it fails → **STOP** and report error.

### Phase 2 — Build + Flash (unless --skip-build)

If `--skip-build` is set, skip this phase entirely.

Otherwise, delegate to **picoruby-dev subagent** with:

```
DEV_COMMAND_CONTEXT=true

Execute the following commands sequentially via Bash tool:
1. rake build APP=<APP>
2. If build succeeds: rake flash
3. Report results (success/failure for each step)

Note: Flash failure (device not connected) is non-fatal — report warning and continue.
```

- Build FAIL → **STOP** and report error
- Flash FAIL → report warning, continue to Phase 3

### Phase 3 — Web Server

Check server status, then start if needed:

```bash
rake server:status
# If not running:
rake server:start
```

Use Bash tool directly (rake server tasks are always permitted).

If server fails to start → **STOP** and report error.

### Phase 4 — Chrome Navigation (unless --no-browser)

Use `mcp__claude-in-chrome__tabs_context_mcp` to check current tabs.
Create a new tab with `mcp__claude-in-chrome__tabs_create_mcp`.
Navigate to `http://localhost:8000/` with `mcp__claude-in-chrome__navigate`.

Wait ~3 seconds for ruby.wasm to initialize.

### Phase 5 — Console Error Check

Use `mcp__claude-in-chrome__read_console_messages` with:
```
pattern: "Error|Uncaught|net::ERR_"
```

Record any matches. Expected: none.

### Phase 6 — ruby.wasm Initialization Check

Use `mcp__claude-in-chrome__read_console_messages` with:
```
pattern: "Ruby|SynthApp|rubySerial"
```

Record matches. Expected: at least one of these strings present.

### Phase 7 — UI Element Check

Use `mcp__claude-in-chrome__get_page_text` to verify:
- Page title contains "picoruby-ot" or "synth"
- "Connect" button text is present

Use `mcp__claude-in-chrome__computer` (screenshot) to visually verify:
- Canvas elements visible (oscilloscope, level meter, etc.)
- Synth graph rendered

### Phase 8 — Screenshot

Capture screenshot with `mcp__claude-in-chrome__computer` and attach to report.

### Phase 9 — Manual Gate (Web Serial)

Web Serial requires a user gesture due to browser security model — automation is not possible.

Notify user with the following instructions:

```
Web Serial の接続には手動操作が必要ですピョン。

1. Chrome ウィンドウで "Connect" ボタンをクリック
2. ポート選択ダイアログで ATOM Matrix の USB ポートを選択
3. "接続" をクリック
4. otmeiwa からのセンサーデータが流れ始めることを確認

確認できたら OK ですピョン！
```

### Phase 10 — Results Report

Output a summary table:

```markdown
## /dev Integration Test Results

| Phase | Item | Result | Notes |
|-------|------|--------|-------|
| 1 | Environment check | ✅/❌ | ... |
| 2 | rake build APP=<APP> | ✅/⏭️/❌ | ... |
| 2 | rake flash | ✅/⚠️/⏭️ | ... |
| 3 | Web server | ✅/❌ | ... |
| 4 | Page load | ✅/❌ | ... |
| 5 | JS errors | ✅/⚠️ | count: N |
| 6 | ruby.wasm init | ✅/❌ | ... |
| 7 | UI elements | ✅/❌ | ... |

**Overall: PASS / PARTIAL / FAIL**

⚠️ Web Serial: 手動接続が必要です（上記 Phase 9 参照）
```

Legend: ✅ pass · ❌ fail · ⚠️ warning · ⏭️ skipped
