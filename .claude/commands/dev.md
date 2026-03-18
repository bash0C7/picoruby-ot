---
name: dev
description: Integration test command — build, flash, start web server, and verify Chrome synth. Add --debug for serial capture.
---

# /dev — Integration Test Command

Delegates all work to the **dev-integration subagent** to protect the main context window.

## Instructions

Parse `$ARGUMENTS` and pass them as-is to the dev-integration subagent via the Agent tool.

```
subagent_type: dev-integration
prompt: $ARGUMENTS
```

Wait for the subagent to complete and return its report to the user.

## Arguments Reference

```
/dev [APP=otmeiwa] [--skip-build] [--no-browser] [--debug [DURATION=60]]
```

- `APP=` : firmware name (default: `otmeiwa`)
- `--skip-build` : skip build+flash
- `--no-browser` : skip Chrome verification
- `--debug` : also capture serial output (default duration: 60s)
- `DURATION=N` : serial capture seconds (only with `--debug`)
