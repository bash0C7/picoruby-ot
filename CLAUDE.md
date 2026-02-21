# picoruby-ot: ATOM Matrix Instrument Project

M5 ATOM Matrix (ESP32-PICO-D4) + R2P2-ESP32 (PicoRuby runtime) embedded development configuration.

ビルドは人間が絶対に行う。ClaudeはNG。

## Core Principles

<simplicity_first>
Avoid complexity. Think carefully before implementing.

**Embedded System Constraints**:
- Shallow nesting only (memory critical: 520KB RAM available)
- Pre-allocate arrays, avoid dynamic allocation
- No complex class hierarchies, exception handling, or deep function calls without explicit user request
- Write simple, linear code by default

**PicoRuby vs CRuby**:
- "Ruby" = CRuby (standard Ruby)
- "PicoRuby" = mruby/c subset (limited stdlib, no bundler, no RubyGems.org)
- ALWAYS think within PicoRuby constraints for .rb files
- .rb files run on PicoRuby/mruby (NOT CRuby)
</simplicity_first>

<output_tone>
**日本語で出力すること**:
- **絶対に日本語で応答・プラン提示すること**
- 通常時: 語尾に「ピョン。」をつけて可愛く
- 盛り上がってきたら:「チェケラッチョ！！」と叫ぶ
- コード内コメント: 日本語、体言止め
- ドキュメント(.md): 英語で記述
- Git commit: 英語、命令形
</output_tone>

<default_to_action>
When implementing changes:
1. Implement proactively WITHOUT asking "should I...?" or "shall I...?"
2. Commit changes IMMEDIATELY after implementation (MUST use subagent `commit`)
3. DO NOT push to remote unless user explicitly requests
4. User will verify functionality AFTER commit (not before)

**Commit immediately to prevent data loss in case of errors**
</default_to_action>

<investigate_before_answering>
**NEVER speculate about code you have not opened**.

When user references files, GPIO, hardware, or existing code:
1. **MUST read files first** before answering
2. **MUST use subagent `explore`** for:
   - Code investigation/exploration
   - Understanding current implementation during plan mode
   - Complex dependency analysis
3. Give grounded, hallucination-free answers based on actual code
4. Read multiple files in parallel when investigating related components
</investigate_before_answering>

<use_parallel_tool_calls>
When reading multiple independent files or searching codebase:
- Read files in parallel (single message, multiple Read tool calls)
- Run Grep searches in parallel when possible
- NEVER use placeholders - wait for actual results if dependencies exist
</use_parallel_tool_calls>

<extended_thinking>
For complex problems:
1. Use "think hard" for multi-step reasoning
2. Reflect carefully on tool results before proceeding
3. Plan iterations based on new information discovered
</extended_thinking>

## Commands

⚠️ **IMPORTANT**: Do NOT execute `rake` commands autonomously without user approval.

**Permissions** (configured in `.claude/settings.local.json`):
- ✅ **Allowed**: `rake monitor`, `rake check_env` (read-only operations)
- ❓ **Ask first**: `rake build`, `rake cleanbuild`, `rake flash` (time-consuming/hardware operations)
- 🚫 **Denied**: `rake init`, `rake update`, `rake buildall` (contain destructive git operations)

```bash
rake init        # Initial setup (DENIED - contains git reset --hard)
rake build       # Build (ASK - build operation)
rake buildall    # Build all (DENIED - same as cleanbuild)
rake cleanbuild  # Clean build (ASK - destructive clean)
rake check_env   # Environment check (ALLOWED - read-only)
rake flash       # Flash to ESP32 (ASK - hardware write)
rake monitor     # Monitor serial output (ALLOWED - debug capture)
rake update      # Update (DENIED - contains git reset --hard)
```

**Rationale**:
- `rake monitor` is allowed for direct debug information capture during development
- Build/flash operations require confirmation to prevent accidental time-consuming operations
- Operations containing `git reset --hard` are completely denied to protect work in progress

## Code Style

**Ruby (.rb files - PicoRuby/mruby)**:
- Embedded constraints: shallow nesting, simplicity first
- Memory-focused: pre-allocate arrays, avoid dynamic allocation
- Comments: Japanese, noun-ending style (体言止め)
- PicoRuby/mruby stdlib ONLY (no CRuby features, no gems)

**Documentation (.md files)**:
- English

**Git Commits**:
- English, imperative mood
- ⚠️ **IMPORTANT**: MUST use subagent `commit` for all commits
- Claude Code MUST NOT execute git commit commands directly
- **Subagent commit workflow**:
  - Proposes commit message AND executes actual commit
  - Completes both git add + git commit
  - ⚠️ **FORBIDDEN**: git push, git push --force (remote operations absolutely prohibited)

## Workflow

<workflow_steps>
0. **Investigation Phase** (MUST use subagent `explore`):
   - Code investigation/exploration
   - Current code review during plan mode
   - Complex dependency understanding

1. **Complex Problem Solving**:
   - Use "think hard" for extended reasoning

2. **Implementation**:
   - Small, incremental changes

3. **Immediate Auto-Commit** (subagent `commit`):
   - Commit BEFORE user testing (prevent data loss on errors)
   - NEVER skip this step

4. **User Verification**:
   - Ask user to verify functionality
</workflow_steps>

## Architecture

- **Arduino C++**: Initialization, ESP-IDF integration
- **PicoRuby**: Application logic (otma.rb, otpwm.rb), LED control, sensors
- **Build System**: ESP-IDF + R2P2-ESP32

**File Locations**:
- Ruby apps: `src_components/R2P2-ESP32/storage/home/` (otma.rb, otpwm.rb)
- Build config: `src_components/R2P2-ESP32/components/picoruby-esp32/picoruby/build_config/xtensa-esp.rb`

## Hardware: ATOM Matrix (ESP32-PICO-D4)

### GPIO Mapping

| Function | GPIO | Notes |
|----------|------|-------|
| MIDI TX | GPIO 22 | PortD/J5 (standard for otma.rb) |
| MIDI RX | GPIO 19 | PortD/J5 (standard for otma.rb) |
| PWM Speaker | GPIO 33 | J4 (otpwm.rb) |
| I2C SDA | GPIO 25 | J3 (otpwm.rb: VL53L0X + MPU6886) |
| I2C SCL | GPIO 21 | J3 (otpwm.rb: VL53L0X + MPU6886) |
| WS2812 Data | GPIO 26 (otpwm) or GPIO 22 (otma) | LED strip control |
| Button | GPIO 39 | ATOM Matrix built-in |

### UART Configuration (MIDI)

```ruby
MIDI_TX_PIN = 22      # PortD/J5 TX
MIDI_RX_PIN = 19      # PortD/J5 RX
UART_UNIT = :ESP32_UART1
BAUDRATE = 31250      # MIDI standard
```

### LED Configuration (WS2812)

```ruby
LED_PIN = 26 or 22    # RMT driver pin
LED_COUNT = 30        # Standard WS2812 strip
```

## Port Configuration

### Available Ports
- **本体Grove**: GPIO26 (TX), GPIO32 (RX) - UART/I2C標準ポート
- **J3**: GPIO25 (SDA), GPIO21 (SCL) - I2C専用（MPU6886, VL53L0X用）
- **J4**: GPIO33 - PWM/アナログ（スピーカー用）
- **PortD/J5**: GPIO22, GPIO19 - UART/GPIO/WS2812用途

## Constraints

- **Memory**: 520KB RAM (ESP32-PICO-D4)
- **Ruby Libraries**: Standard library only (no gems)
- **Code**: Shallow nesting, avoid complex classes
- **Character Encoding**: UTF-8

## Environment

- **ESP-IDF**: `$HOME/esp/esp-idf/` (auto-configured by rake)
- **Flash Speed**: 115200 bps
- **Build Target**: ESP32 (Xtensa)

---

## Projects

### otma.rb - Auto Drum Machine (MIDI)

**概要**: M5 ATOM Matrix でMIDI音源を制御する自動ドラムマシン。リズムパターンに同動したLED演出。

**ハードウェア**:
- MIDI音源: SAM2695等のMIDI Unitモジュール（GPIO22/19で接続）
- LED: WS2812 LEDストリップ 30個
- ボタン: GPIO39（ATOM Matrix内蔵）

**機能**:
- 16ステップドラムパターンループ自動演奏
- リズムに連動したLED色変化
- ボタンでクラッシュシンバル発音

### otpwm.rb - Distance Sensor Instrument

**概要**: 距離センサーと加速度センサーを使った電子ノイズ楽器。攻撃的な電子音とアンビエントなLED演出。

**ハードウェア**:
- 距離センサー: VL53L0X（Unit ToF）
- 加速度センサー: MPU6886（内蔵）
- スピーカー: PWM制御Grove互換スピーカー（GPIO33）
- LED: WS2812 LEDストリップ 30個
- ボタン: GPIO39（ATOM Matrix内蔵）

**機能**:
- 距離→周波数マッピング（20mm-300mm → 200Hz-1000Hz）
- 加速度でduty制御と音色変化
- ノイズフェード処理（範囲外）
- LED波形オフセット演出

---

**Note**: Keep this config file concise. Detailed information auto-loads only when needed.
