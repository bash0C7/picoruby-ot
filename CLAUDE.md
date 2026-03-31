# picoruby-ot: ATOM Matrix Instrument Project

M5 ATOM Matrix (ESP32-PICO-D4) + R2P2-ESP32 (PicoRuby runtime) + Chrome Web Synth.

**ビルドは人間が絶対に行う。ClaudeはNG。**

## Core Principles

<simplicity_first>
**Embedded constraints** (all `.rb` files in `storage/home/`):
- Shallow nesting only (520KB RAM)
- Pre-allocate arrays, avoid dynamic allocation
- PicoRuby/mruby subset ONLY — not CRuby

**Prohibited in PicoRuby**: `defined?`, `Hash#fetch`, `String#reverse`, `String#rjust`, inline `rescue`, `proc`, `lambda`
</simplicity_first>

<output_tone>
**日本語で出力すること**:
- 通常時: 語尾に「ピョン。」をつけて可愛く
- 盛り上がってきたら:「チェケラッチョ！！」と叫ぶ
- コード内コメント: 日本語、体言止め
- ドキュメント(.md): 英語で記述
- Git commit: 英語、命令形
</output_tone>

<default_to_action>
When implementing:
1. Implement proactively WITHOUT asking "should I...?"
2. Commit IMMEDIATELY after implementation (MUST use subagent `commit`)
3. DO NOT push to remote unless user explicitly requests
</default_to_action>

<investigate_before_answering>
**NEVER speculate about code you have not opened.**
Read files first. Use subagent `explore` for complex investigations.
</investigate_before_answering>

<debugging_protocol>
**Before ANY fix, read the relevant source:**
- GPIO pins → check `src_components/R2P2-ESP32/CLAUDE.md` GPIO Mapping table FIRST
- Config fields, JSON paths → read the actual config/source file
- DOM selectors → read `web/index.html` before assuming attribute names
- API method names → grep the codebase, never guess

Do NOT propose a fix until you have quoted the current value from source.
</debugging_protocol>

<scope_discipline>
**Only modify files explicitly in scope for the current task.**
- If you identify a needed change outside scope, TELL THE USER and wait
- Never touch files in sibling apps (e.g. don't edit otma.rb when working on otmeiwa.rb)
- Sub-agents: state your scope at the start and reject out-of-scope file edits
</scope_discipline>

<permissions>
**Always use minimal/least-privilege.**
- Never propose wildcard tool permissions
- Request only the specific tools/files needed for the task
- If unsure what's needed, ask rather than broadening scope
</permissions>

## Commands

⚠️ Do NOT execute `rake` commands autonomously without user approval.

| Command | Permission |
|---------|-----------|
| `rake monitor`, `rake check_env` | ✅ Allowed |
| `rake build APP=xxx`, `rake cleanbuild`, `rake flash` | ❓ Ask first |
| `rake init`, `rake update`, `rake buildall` | 🚫 Denied |

## Code Style

- **Ruby** (PicoRuby): shallow nesting, integer math, pre-allocated arrays, Japanese comments (体言止め)
- **Documentation** (.md): English
- **Git commits**: English, imperative mood, conventional commits style

## Workflow

0. **Investigate** (subagent `explore` for complex tasks)
1. **Implement** (small, incremental changes)
2. **Commit immediately** (subagent `commit` — NEVER skip, prevents data loss)
3. **User verifies** (build/flash/test in Chrome)

## Commit Rule

- ⚠️ MUST use subagent `commit` — Claude Code MUST NOT execute git commit directly
- ⚠️ FORBIDDEN: git push, git push --force

## Architecture

```
src_components/R2P2-ESP32/storage/home/
├── otma.rb      → MIDI auto drum machine (GPIO22=MIDI TX)
├── otpwm.rb     → PWM speaker instrument (GPIO33=PWM, GPIO25/21=I2C)
└── otmeiwa.rb   → Serial sensor → Chrome synth (UART0/USB=115200bps)

web/
├── index.html   → Single-file Chrome synth (ruby.wasm + Web Audio)
└── src/ruby/    → SynthApp, SerialManager, SynthPatch DSL, SensorMapper
```

Hardware detail: See `src_components/R2P2-ESP32/CLAUDE.md`
Web synth detail: See `web/CLAUDE.md`

## Sub-Agents & Skills

**Sub-agents** (`.claude/agents/`):
- `picoruby-dev` — PicoRuby embedded code (otma/otpwm/otmeiwa)
- `web-synth-dev` — Web synth (index.html, ruby.wasm, Web Audio)

**Skills** (`.claude/skills/`):
- `picoruby-build` — Build/flash/monitor workflow
- `sensor-serial` — Serial protocol debugging
- `finger-drum` — Finger drum system (DDJ-400 + ATOM)
- `led-visualization` — WS2812 LED patterns

## Projects

### otma.rb — Auto Drum Machine (MIDI)

16-step drum patterns, WS2812 LED sync, button=crash cymbal.
MIDI Unit via GPIO22(TX)/19(RX) at 31250bps. 30 LEDs on GPIO22.

### otpwm.rb — PWM Distance Instrument

Distance 20–300mm → 200–1000Hz via GPIO33 PWM speaker.
VL53L0X + MPU6886 via I2C (GPIO25/21). 29 LEDs on GPIO26.

### otmeiwa.rb — Sensor Serial Output

Sends `<D:NNNN,AX:NNNN,AY:NNNN,AZ:NNNN>` at ~20fps via UART0/USB.
Distance 20–900mm. Accel calibration on button press.
15 LEDs on GPIO26: hue=distance, sat=accel magnitude.

### web/ — Portamento Drone FM Synthesizer (Chrome)

ruby.wasm app. Web Serial 115200bps from otmeiwa.rb.
Always-on drone. Distance→continuous pitch (portamento, no note snap), accel→FM depth.
Glide TC=40ms ≈ 20fps frame period for smooth inter-frame pitch interpolation.
Canvas: oscilloscope, level meter, accel curve.
Operational distance range: 30–570mm → MIDI 48–72 (2 octaves, ~23mm/semitone).
