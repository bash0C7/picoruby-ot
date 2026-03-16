# Ruby WASM Sound Visualizer

Browser-based audio visualizer (VJ software) written in Ruby and executed via ruby.wasm.

## Table of Contents

1. [Overview](#overview)
2. [Language Policy](#language-policy)
3. [Development Guidelines](#development-guidelines)
   - [Git Operations](#git-operations)
   - [Implementation Approach](#implementation-approach)
   - [Investigation Protocol](#investigation-protocol)
   - [Browser Testing & Debugging](#browser-testing--debugging)
4. [Technical Specifications](#technical-specifications)
   - [Technology Stack](#technology-stack)
   - [Architecture](#architecture)
   - [File Structure](#file-structure)
5. [Project Skills](#project-skills)
6. [Quick Start](#quick-start)
7. [References](#references)

## Overview

Real-time audio visualizer that analyzes microphone input and generates vivid 3D visual effects using Three.js. Nearly all logic is implemented in Ruby and executed in the browser via @ruby/4.0-wasm-wasi.

## Language Policy

- **Documentation, git comments, code comments**: ALL in English
- **User communication, information provision**: ALL in Japanese Kansai dialect (関西弁)
- **README.md**: ABSOLUTE RULE - ALL in English, no bold emphasis (`**`), no emoji, fact-based language without hyperbole

## Development Guidelines

### Git Operations

- **Use subagent**: Delegate git operations to Task tool subagent (exception: Claude Code Web allows direct git operations via skills including git push)
- **Push policy**: Push allowed from Claude Code on web only. Local sessions stop at commit (manual push by humans).
- **Commit message format**: English only, follow conventional commits style
- **File moves**: Always use `git mv` instead of copy+delete. After renaming/moving files, update ALL referencing files (index.html, require statements, etc.) and verify with browser testing.

### Implementation Approach

- **t-wada Style TDD**: Develop using Red → Green → Refactor cycle
  - Always start with failing test. Write test before production code.
  - Proceed carefully with test-first approach to avoid breaking existing functionality.
- **Ruby-first implementation**: Implement logic in Ruby as much as possible
- **VisualizerPolicy as single source of truth**: All tunable constants and parameters belong in `VisualizerPolicy`. Individual classes reference `VisualizerPolicy::CONSTANT_NAME` rather than defining their own. This centralizes tuning, enables runtime mutability via `RUNTIME_PARAMS`, and keeps JS/Ruby slider sync in one place.
- **Observability**: Log key state transitions and quantitative parameter values via `JSBridge.log`. Follow OpenTelemetry semantic conventions for attribute naming (e.g., `audio.bpm`, `effect.type`, `synth.frequency`). Output destination is browser console. Log on state change, not every frame.
- **Scope adherence**: Only modify files specified by user
- **Build/deploy prohibition**: Do not execute unless explicitly instructed
- **Minimal changes**: Targeted changes, not broad refactoring
- **No speculation-based fixes**: Propose investigation instead
- **Critical files**: index.html and Gemfile require explicit user approval before modification

### Investigation Protocol

**CRITICAL: Never fix based on speculation. Always verify facts with debug output before fixing.**

1. Record phenomenon accurately (what is happening)
2. Confirm expected behavior (what should happen)
3. Identify differences (what is different)
4. Formulate hypotheses (max 3, with rationale)
5. Verify with debug output (one at a time)
6. Apply minimal fix
7. Verify with Chrome MCP tools

**Key rules**: max 3 hypotheses, verify one at a time, use `console.log` to confirm facts before fixing.

See [.claude/INVESTIGATION-PROTOCOL.md](.claude/INVESTIGATION-PROTOCOL.md) for detailed workflow.

### Browser Testing & Debugging

**Chrome MCP tools required**: ALWAYS use Chrome MCP tools (`mcp__claude-in-chrome__*`) for browser verification.

**CRITICAL: Never claim something works without actual Chrome MCP verification. Do not report completion until screenshot and console check confirm it.**

- **Cache busting**: ruby.wasm aggressively caches. Always use `?nocache=<random>` in URL when testing. If changes seem invisible, suspect caching first.
- **Console multi-tab pollution**: Chrome console shows messages from ALL open tabs in the same window. When checking for errors, confirm the URL in the message source (e.g., `nocache=XXXXX`) matches your current session. Errors from stale cached tabs appear alongside current session logs and cause false positives.
- **JS::Object nil? prohibition**: Never use `.nil?` on `JS::Object` instances — it always returns `false` (BasicObject). Use `.typeof == "undefined"` instead.

Use `/debug-browser` skill for detailed procedures. Use `/verify` skill for the full TDD + browser confirmation loop.

## Technical Specifications

### Technology Stack

- **Ruby 3.4.7** (via @ruby/4.0-wasm-wasi 2.8.1)
- **Three.js** (0.160.0) - 3D rendering & post-processing
- **Web Audio API** - Microphone input & frequency analysis
- **Web Serial API** - Hardware device communication (ATOM Matrix LED) and PicoRuby frequency data reception

### Architecture

See [.claude/ARCHITECTURE.md](.claude/ARCHITECTURE.md) for detailed architecture documentation.

### File Structure

```
index.html              # Single file containing all code (Ruby + JavaScript + HTML)
src/ruby/               # Ruby source files
├── plugins/            # VJ Pad plugin commands
│   ├── vj_burst.rb           # Burst effect (impulse injection)
│   ├── vj_flash.rb           # Flash effect (bloom flash)
│   ├── vj_shockwave.rb       # Shockwave effect (bass impulse + bloom)
│   ├── vj_strobe.rb          # Strobe effect (quick bloom flash)
│   ├── vj_rave.rb            # Rave preset (max energy + param boost)
│   ├── vj_serial.rb          # Web Serial plugin (connect/send/receive)
│   └── vj_wordart.rb         # WordArt text effect plugin
├── main.rb                   # Application entry point and initialization
├── js_bridge.rb              # Ruby-JavaScript interoperability bridge
├── vj_plugin.rb              # Plugin system core (VJPlugin + PluginDefinition)
├── vj_pad.rb                 # VJ Pad DSL (delegates to plugins)
├── vj_serial_commands.rb     # VJ Pad serial command handler
├── vj_synth_patch_commands.rb # VJ Pad synth patch command handler
├── effect_dispatcher.rb      # Plugin effects → EffectManager translator
├── effect_manager.rb         # Coordinates all visual effects
├── audio_input_manager.rb    # Microphone input management
├── audio_analyzer.rb         # Frequency spectrum analysis
├── audio_limiter.rb          # Audio dynamic range control
├── frequency_mapper.rb       # Frequency to visual parameter mapping
├── bpm_estimator.rb          # BPM detection and tracking
├── camera_controller.rb      # Three.js camera controls
├── bloom_controller.rb       # Bloom post-processing effect control
├── geometry_morpher.rb       # Mesh morphing and transformation
├── particle_system.rb        # Particle effect system
├── color_palette.rb          # Color management and palette operations
├── vrm_dancer.rb             # VRM avatar animation control
├── vrm_material_controller.rb # VRM model material management
├── serial_protocol.rb        # ASCII serial frame format (encode/decode)
├── serial_manager.rb         # Serial connection state machine
├── serial_audio_source.rb    # Serial PWM audio output state management
├── synth_patch/              # DSL-based synthesizer patch system
│   ├── synth_patch.rb        # Patch DSL, node graph builder, note control
│   ├── node.rb               # Base class for synthesis graph nodes
│   ├── osc_node.rb           # Basic oscillator node (sine/square/saw/tri)
│   ├── fm_op_node.rb         # FM modulation operator node
│   ├── filter_node.rb        # Biquad filter node (lowpass/highpass/bandpass)
│   ├── gain_node.rb          # Gain (volume) control node
│   ├── mixer_node.rb         # Multi-input mixer node
│   ├── audio_adapter.rb      # Abstract audio backend interface
│   ├── web_adapter.rb        # Web Audio API adapter (production)
│   └── mock_adapter.rb       # Test adapter (records calls)
├── oscilloscope_renderer.rb  # 3D oscilloscope waveform visualization state
├── wordart_renderer.rb       # 90s WordArt text animation engine
├── pen_input.rb              # Mouse pen drawing with fade-out
├── keyboard_handler.rb       # Keyboard input event handling
├── snapshot_manager.rb       # Save/load visualizer state
├── visualizer_policy.rb      # Visualization policy and mode management
├── debug_formatter.rb        # Debug output formatting utilities
├── frame_counter.rb          # Frame counting and timing
└── math_helper.rb            # Mathematical utility functions
lib/
└── dev_server.rb       # Development HTTP server (used by rake server:start)
picoruby/               # PicoRuby firmware (two apps)
├── CLAUDE.md                 # PicoRuby project instructions
├── AGENTS.md                 # Symlink to CLAUDE.md
├── SERIAL_AUDIO_PROTOCOL.md  # Serial audio protocol spec (PicoRuby → Chrome)
├── Rakefile                  # Build automation (rake build/flash/monitor)
├── .claude/
│   └── settings.local.json   # Rake command permissions
└── src_components/           # Source components (git-tracked)
    └── R2P2-ESP32/
        ├── sdkconfig.defaults
        ├── storage/home/
        │   ├── led_visualizer.rb   # LED VU meter firmware (ATOM Matrix 5x5 WS2812, APP=led_visualizer)
        │   └── otv.rb              # Theremin instrument firmware (R2P2-ESP32, APP=otv)
        └── components/picoruby-esp32/
            ├── CMakeLists.txt
            └── picoruby/
                ├── build_config/xtensa-esp.rb
                └── mrbgems/{picoruby-ws2812,picoruby-irq}/
.claude/                # Project-specific configuration & documentation
├── settings.json       # Project-level hooks (rubocop + test, shared across environments)
├── ARCHITECTURE.md     # Architecture details
├── INVESTIGATION-PROTOCOL.md  # Investigation protocol
├── RUBY-WASM.md        # Ruby WASM specific knowledge
├── SETUP.md            # Setup & execution instructions
├── tasks.md            # Project task list
├── plan.md             # Implementation plan scratch pad
├── guides/             # Technical reference guides
│   ├── plugin-development.md  # VJ Pad plugin development guide
│   ├── 3d-basics.md          # Three.js 3D fundamentals
│   ├── 3d-glossary.md        # 3D programming & shader glossary
│   ├── shader-operations.md  # Post-processing & shader guide
│   ├── vrm.md                # VRM model integration guide
│   ├── js-ruby-wasm-interop.md  # JS-Ruby interop patterns
│   ├── ruby-wasm-technical.md   # ruby.wasm platform guide
│   └── picoruby-instrument.md   # PicoRuby theremin instrument guide
└── skills/             # Project-local skills
    ├── create-plugin/  # Scaffold new VJ Pad plugin
    ├── debug-browser/  # Browser debugging procedures
    ├── browser-clean-session/  # Clean browser session
    ├── rake-picoruby/  # PicoRuby rake operations (build/flash/monitor)
    ├── troubleshoot/   # Basic troubleshooting
    ├── verify/         # TDD + Chrome browser confirmation loop
    └── visualizer-test/  # Browser-based visualizer smoke test
```

## Project Skills

This project defines local skills in `.claude/skills/`. Use skills via Skill tool (e.g., `/debug-browser`).

Available skills:
- **create-plugin**: Scaffold a new VJ Pad plugin with test file and registration
- **debug-browser**: Detailed browser debugging procedure for ruby.wasm app using Chrome MCP tools
- **browser-clean-session**: Open visualizer in clean browser session with full cache clear
- **rake-picoruby**: Run PicoRuby build/flash/monitor operations (filters verbose rake output to key information only)
- **troubleshoot**: Basic troubleshooting guide
- **verify**: Full TDD + Chrome browser confirmation loop (rake test → hard refresh → screenshot → console check)
- **visualizer-test**: Browser-based visualizer smoke test (VJ Pad, VRM, key input verification)

Skills are project-local and defined within this repository.

### Hooks (Automated Quality Checks)

Project-level hooks are defined in `.claude/settings.json` (shared across Web and CLI environments). On every `Edit` or `Write` tool use, the following runs automatically:

1. `bundle exec rubocop -a src/ruby/ test/` -- auto-fix style offenses
2. `bundle exec rake test` -- run full test suite

Environment-specific settings (permissions, UI preferences) live in `.claude/settings.local.json`.

### PicoRuby Build Operations

For all PicoRuby build, flash, and monitor operations, delegate to `/rake-picoruby` skill to filter verbose logs and extract essential information. This minimizes context window pollution.

## Quick Start

See [.claude/SETUP.md](.claude/SETUP.md) for detailed setup instructions.

### Using Rake Tasks

```bash
# Start server
bundle exec rake server:start

# Check status
bundle exec rake server:status

# Stop server
bundle exec rake server:stop

# Run tests
bundle exec rake test
```

### Manual Server Control

```bash
bundle install
bundle exec ruby -run -ehttpd . -p8000
```

Open `http://localhost:8000/index.html` in browser.

## Technical Guides

Reference guides for technologies used in this project (located in `.claude/guides/`):

- [Plugin Development](.claude/guides/plugin-development.md) - VJ Pad plugin system DSL and effect API
- [3D Basics](.claude/guides/3d-basics.md) - Three.js scene, camera, geometry, animation
- [3D Glossary](.claude/guides/3d-glossary.md) - 3D programming, modeling & shader terminology
- [Shader Operations](.claude/guides/shader-operations.md) - Post-processing, bloom, materials
- [VRM Guide](.claude/guides/vrm.md) - VRM model loading, bones, expressions
- [JS-Ruby Interop](.claude/guides/js-ruby-wasm-interop.md) - JavaScript & ruby.wasm integration
- [ruby.wasm Technical](.claude/guides/ruby-wasm-technical.md) - ruby.wasm platform specifics
- [PicoRuby Theremin Instrument](.claude/guides/picoruby-instrument.md) - otv.rb signal flow, hardware, and key classes

## References

- [ruby.wasm Official Documentation](https://ruby.github.io/ruby.wasm/)
- [Three.js Documentation](https://threejs.org/docs/)
- [Web Audio API - MDN](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)
- [ruby.wasm JavaScript Interop Guide](./.claude/RUBY-WASM.md) - Project-specific knowledge
