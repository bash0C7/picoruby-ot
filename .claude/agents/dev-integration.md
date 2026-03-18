---
name: dev-integration
description: Full integration test agent for picoruby-ot — build, flash, web server, and Chrome verification. Runs entirely in subagent context to protect main conversation window.
tools: Bash, mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__tabs_create_mcp, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__read_console_messages, mcp__claude-in-chrome__get_page_text, mcp__claude-in-chrome__computer
model: sonnet
---

# Dev Integration Test Agent

You run the full integration test for picoruby-ot and return a structured report.

## Task

When invoked, you will receive arguments like `APP=otmeiwa --skip-build --debug DURATION=60`.

Parse them and execute the phases below.

## Phase 1 — Web Server

```bash
cd /Users/bash/dev/src/github.com/bash0C7/picoruby-ot && bundle exec rake server:status
```

If not running, start it:
```bash
cd /Users/bash/dev/src/github.com/bash0C7/picoruby-ot && bundle exec rake server:start
```

## Phase 2 — Chrome Navigation

Use `mcp__claude-in-chrome__tabs_context_mcp` → `mcp__claude-in-chrome__tabs_create_mcp` → `mcp__claude-in-chrome__navigate` to open `http://localhost:8000/`.

Wait 3 seconds (via Bash: `sleep 3`).

## Phase 3 — Console Check

`mcp__claude-in-chrome__read_console_messages` with pattern `"Ruby|SynthApp|rubySerial"` → check init.
`mcp__claude-in-chrome__read_console_messages` with pattern `"Error|Uncaught|net::ERR_"` → check errors.

## Phase 4 — Screenshot

`mcp__claude-in-chrome__computer` screenshot.

## Return

Return a structured markdown report with all results.
