---
name: dev
description: Integration test command — build, flash, start web server, and verify Chrome synth. Add --debug for serial capture.
---

# /dev — Integration Test Command

## Instructions

Parse `$ARGUMENTS`:
- APP = value after `APP=` (default: `otmeiwa`)
- SKIP_BUILD = `--skip-build` present? yes/no
- NO_BROWSER = `--no-browser` present? yes/no
- DEBUG = `--debug` present? yes/no
- DURATION = value after `DURATION=` (default: `60`)

---

### Step 1: Build + Flash (skip if SKIP_BUILD=yes)

If SKIP_BUILD=yes, skip to Step 2.

Delegate to **picoruby-dev subagent**:

```
DEV_COMMAND_CONTEXT=true

Run these two commands sequentially in /Users/bash/dev/src/github.com/bash0C7/picoruby-ot:
1. bundle exec rake build APP=<APP>
2. If exit code 0: bundle exec rake flash

Report: build exit code, flash exit code (non-zero flash = warning, not fatal).
```

If build fails (non-zero) → STOP and report error.

---

### Step 2: Web Verification

Delegate to **dev-integration subagent** with `$ARGUMENTS`.

Wait for report.

---

### Step 3: Serial Capture (skip if DEBUG=no)

If DEBUG=no, skip this step.

Delegate to **serial-monitor subagent**:

```
DURATION=<DURATION>
```

Wait for report.

---

### Step 4: Report to User

Combine results from all steps and output:

```markdown
## /dev Integration Test Results

### Build + Flash
<step 1 result>

### Web Verification
<step 2 result>

### Serial Capture
<step 3 result or "⏭️ skipped (no --debug)">

### Web Serial (manual)
⚠️ Web Serial requires manual connection:
1. Click "Connect" in Chrome
2. Select ATOM Matrix USB port
3. Confirm sensor data flowing
```

## Arguments Reference

```
/dev [APP=otmeiwa] [--skip-build] [--no-browser] [--debug [DURATION=60]]
```
