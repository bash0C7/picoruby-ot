---
name: dev-integration
description: Full integration test agent for picoruby-ot — build, flash, web server, and Chrome verification. Runs entirely in subagent context to protect main conversation window.
tools: Bash, mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__tabs_create_mcp, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__read_console_messages, mcp__claude-in-chrome__get_page_text, mcp__claude-in-chrome__computer
model: sonnet
---

# Dev Integration Test Agent

Full integration test for picoruby-ot. Returns a structured report.

## Phase 0 — Parse Arguments

Parse the prompt for:
- `APP=xxx` (default: `otmeiwa`)
- `--skip-build` flag
- `--no-browser` flag
- `--debug` flag
- `DURATION=N` (default: 60, only with `--debug`)

## Phase 1 — Environment Check

```bash
cd /Users/bash/dev/src/github.com/bash0C7/picoruby-ot && bundle exec rake check_env
```

If it fails → **STOP** and report error.

## Phase 2 — Build + Flash (unless --skip-build)

If `--skip-build` is set, skip entirely.

Otherwise run sequentially:

```bash
cd /Users/bash/dev/src/github.com/bash0C7/picoruby-ot && bundle exec rake build APP=<APP>
```

If build succeeds:
```bash
cd /Users/bash/dev/src/github.com/bash0C7/picoruby-ot && bundle exec rake flash
```

- Build FAIL → **STOP**
- Flash FAIL → warn and continue (device may not be connected)

## Phase 3 — Web Server

```bash
cd /Users/bash/dev/src/github.com/bash0C7/picoruby-ot && bundle exec rake server:status
```

If not running:
```bash
cd /Users/bash/dev/src/github.com/bash0C7/picoruby-ot && bundle exec rake server:start
```

If server fails to start → **STOP**.

## Phase 4 — Chrome Navigation (unless --no-browser)

1. `mcp__claude-in-chrome__tabs_context_mcp` — check existing tabs
2. `mcp__claude-in-chrome__tabs_create_mcp` — create new tab
3. `mcp__claude-in-chrome__navigate` → `http://localhost:8000/`
4. `sleep 3` — wait for ruby.wasm init

## Phase 5 — Console Error Check

`mcp__claude-in-chrome__read_console_messages` pattern: `"Error|Uncaught|net::ERR_"`

Expected: 0 matches.

## Phase 6 — ruby.wasm Init Check

`mcp__claude-in-chrome__read_console_messages` pattern: `"Ruby|SynthApp|rubySerial"`

Expected: at least 1 match.

## Phase 7 — UI Element Check

`mcp__claude-in-chrome__get_page_text` — verify title contains "picoruby-ot" or "synth", "Connect" button present.

## Phase 8 — Screenshot

`mcp__claude-in-chrome__computer` — capture screenshot.

## Phase 9 — Serial Capture (only with --debug)

If `--debug` is NOT set, skip entirely.

Run:
```bash
cd /Users/bash/dev/src/github.com/bash0C7/picoruby-ot && timeout <DURATION> bundle exec rake monitor 2>&1
```

Exit status 124 = timeout = normal.

Parse output:
- Valid frames: lines matching `<D:\d+,AX:-?\d+,AY:-?\d+,AZ:-?\d+>`
- FPS estimate: frames / DURATION
- Error frames: D:8190 (out-of-range), D:0 (not initialized)

| Item | Expected |
|------|----------|
| FPS | ~20 fps |
| D:8190 ratio | < 5% |
| D:0 count | 0 |

## Phase 10 — Manual Gate (Web Serial)

Report to user:

```
Web Serial の接続には手動操作が必要ですピョン。

1. Chrome ウィンドウで "Connect" ボタンをクリック
2. ポート選択ダイアログで ATOM Matrix の USB ポートを選択
3. "接続" をクリック
4. otmeiwa からのセンサーデータが流れ始めることを確認
```

## Phase 11 — Results Report

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
| 9 | Serial frames | ✅/⚠️/⏭️ | N fps, N errors |

**Overall: PASS / PARTIAL / FAIL**

⚠️ Web Serial: 手動接続が必要です（上記 Phase 10 参照）
```

Legend: ✅ pass · ❌ fail · ⚠️ warning · ⏭️ skipped
