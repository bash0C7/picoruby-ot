---
name: dev
description: Integration test command — build, flash, start web server, and verify Chrome synth. Add --debug for serial capture.
---

# /dev — Integration Test Command

## Instructions

Parse `$ARGUMENTS`:
- APP = value after `APP=` (default: `otmeiwa`)
- SKIP_BUILD = `--skip-build` present? yes/no
- DEBUG = `--debug` present? yes/no
- DURATION = value after `DURATION=` (default: `60`)

### Step 1: Build + Flash (skip if --skip-build)

If SKIP_BUILD=yes, skip to Step 2.

Delegate to **picoruby-dev subagent**:

```
DEV_COMMAND_CONTEXT=true

Run these two commands in /Users/bash/dev/src/github.com/bash0C7/picoruby-ot:
1. bundle exec rake build APP=<APP>
2. If exit code 0: bundle exec rake flash

Report: build exit code, flash exit code (non-zero flash = warning, not fatal).
```

If build fails → STOP and report error.

### Step 2: Web + Serial verification

Delegate to **dev-integration subagent** with the original arguments:

```
<original $ARGUMENTS>
```

Wait for report and return it to the user.

## Arguments Reference

```
/dev [APP=otmeiwa] [--skip-build] [--no-browser] [--debug [DURATION=60]]
```

- `APP=` : firmware name (default: `otmeiwa`)
- `--skip-build` : skip build+flash
- `--no-browser` : skip Chrome verification
- `--debug` : also capture serial output (default duration: 60s)
- `DURATION=N` : serial capture seconds (only with `--debug`)
