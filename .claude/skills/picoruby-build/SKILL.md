---
name: picoruby-build
description: PicoRuby firmware build, flash, and serial monitor operations for ATOM Matrix. Use when building or flashing otma/otpwm/otmeiwa firmware, or monitoring serial output.
disable-model-invocation: true
---

# PicoRuby Build & Flash Operations

⚠️ **ビルドは人間が必ず実行する。Claudeは直接 rake build/flash を実行しない。**

## Available Commands

```bash
rake check_env              # Environment check (Claude can run)
rake monitor                # Serial monitor (Claude can run, Ctrl+C to exit)
rake build APP=otma         # Build drum machine (ASK USER FIRST)
rake build APP=otpwm        # Build PWM instrument (ASK USER FIRST)
rake build APP=otmeiwa      # Build serial sensor output (ASK USER FIRST)
rake flash                  # Flash to ESP32 (ASK USER FIRST)
rake cleanbuild             # Full rebuild (ASK USER FIRST, slow)
```

## Build Workflow

1. User edits `.rb` file in `storage/home/`
2. Claude commits changes immediately (before user builds)
3. User runs: `rake build APP=<name> && rake flash`
4. User runs: `rake monitor` to verify output
5. Claude analyzes monitor output if user shares it

## App → File Mapping

| APP= value | File             | Output |
|------------|------------------|--------|
| otma       | otma.rb          | MIDI via GPIO22 |
| otpwm      | otpwm.rb         | PWM speaker via GPIO33 |
| otmeiwa    | otmeiwa.rb       | Serial frames via UART0/USB |

## Serial Monitor (otmeiwa)

Expected output at ~20fps:
```
<D:250,AX:12,AY:-8,AZ:3>
<D:248,AX:11,AY:-9,AZ:2>
```

Troubleshooting:
- No output: check I2C connections (GPIO25=SDA, GPIO21=SCL)
- `D:8190`: VL53L0X out of range (>900mm or sensor error)
- `D:0`: sensor not initialized, check I2C address 0x29

## Build Environment

- ESP-IDF: `$HOME/esp/esp-idf/`
- Target: ESP32 (Xtensa)
- Flash baud: 115200
- Initialized by rake (auto-sourced)

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `undefined method 'xxx'` | PicoRuby doesn't support it | Use simpler Ruby |
| `NoMemoryError` | 520KB limit exceeded | Reduce array sizes, nesting |
| `I2C timeout` | Wiring issue | Check GPIO25/21 connections |
| Flash fails | Port busy | Close serial monitor first |

## Exception: /dev Command Context

When this skill is invoked via the `/dev` slash command with `DEV_COMMAND_CONTEXT=true`,
Claude (picoruby-dev subagent) **may** run `rake build` and `rake flash` directly.
This is an intentional override for integration testing workflows only.
