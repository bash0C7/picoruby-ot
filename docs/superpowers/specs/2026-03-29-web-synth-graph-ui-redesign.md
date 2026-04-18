# Web Synth Graph-Centric UI Redesign

## Overview

Redesign the Chrome web synthesizer UI around an interactive Synth Patch Graph as the primary control surface. Replace all scattered slider/dropdown sections with inline controls embedded directly in graph nodes. Minimize JavaScript to glue code; all logic and DOM/Web Audio control via ruby.wasm (`require "js"`).

**Target:** Chrome for macOS 146.0.7680.165+

## Goals

1. **Instant pitch response** — configurable frequency smoothing (Glide slider, 0-50ms, default 5ms)
2. **Octave transpose** — Up/Down buttons, +/-2 octaves (semitone resolution, mixed sharp/flat notation)
3. **Interactive Synth Patch Graph** — inline sliders/dropdowns on each node, no click-to-edit
4. **Sensor mapping curves** — preset curve selection (Linear/Log/Exp/S-curve) with visual graph
5. **Simplified envelope** — Attack/Release only (Decay/Sustain removed), triggered by distance range entry/exit
6. **Stateless gain control** — default gain=0, no @sounding flag; setTargetAtTime handles transitions

## Architecture

### Control Principle

```
HTML: Layout definition only (static structure, width: 100vw)
CSS:  Styling only
JS:   Glue code only (ruby.wasm loader, minimal event bridge)
Ruby: All control via require "js" + JS.global
      - DOM manipulation (JS.global[:document].querySelector...)
      - Web Audio API (JS.global[:AudioContext].new...)
      - Web Serial API (JS.global[:navigator][:serial]...)
      - Canvas drawing (getContext("2d"))
      - All logic and state management
```

### File Structure

```
web/src/ruby/
  main.rb              — App loop (redesign)
  sensor_mapper.rb     — Mapping + curve presets (extend)
  synth_patch/
    synth_patch.rb     — Patch DSL (keep)
    node.rb            — Node definition (keep)
    web_adapter.rb     — Web Audio direct control via JS.global (redesign)
  preset_manager.rb    — Preset management (keep)
  ui_controller.rb     — NEW: Graph UI rendering + controls
```

## UI Layout (16:9 Wide, 100vw)

```
+----------------------------------------------------------------------------------------------+
| [Connect] [Disconnect] [Init Audio]  Status: *              Note: C#4  277Hz  150mm          |
+----------------------------------------------------------------------------------------------+
|                                                                                              |
|  +-----------+       +-----------+       +-----------+       +-----------+                    |
|  |  FM Mod   |--FM-->|FM Carrier |------>|   Mixer   |------>|  Filter   |                    |
|  |           |       |           |       |           |       |           |                    |
|  | [v wave ] |       | [v wave ] |       | [= gain ] |       | [v type ] |                    |
|  | [= freq ] |       |           |       |           |       | [= cutoff]|                    |
|  | [= amp  ] |       |           |       |           |       | [= Q    ] |                    |
|  +-----------+       +-----------+       +-----------+       +-----+-----+                    |
|                                                                    |                          |
|                                                               +----v-----+                    |
|                                                               |  Master  |                    |
|                                                               | [= gain] | -> speaker         |
|                                                               +----------+                    |
|                                                                                              |
+----------------------------------------------+-----------------------------------------------+
|  Sensor Mapping Curves                       |  Transport                                    |
|                                              |                                               |
|  Dist -> Pitch    Accel -> FM Depth          |  [Otamatone] [Clean] [Acid] [Retro]           |
|  [Lin|Log|Exp|S]  [Lin|Log|Exp|S]           |                                               |
|  +-------------+  +-------------+            |  Scale [Penta|Maj|Min|Chrom]                  |
|  |      /-     |  |      /-     |            |                                               |
|  |    /        |  |    /        |            |  Octave  [< -2] . . o . . [+2 >]              |
|  |  /          |  |  /          |            |                                               |
|  |/            |  |/            |            |  Glide [====|====] 5ms  Attack [===] Release [===] |
|  +-------------+  +-------------+            |                                               |
+----------------------------------------------+-----------------------------------------------+
|  [Oscilloscope ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~]  [Level ||||||||...........]       |
+----------------------------------------------------------------------------------------------+
|  > Serial Monitor (collapsible, below fold)                                                  |
|  <D:0150,AX:0012,AY:-0005,AZ:1002>                                                         |
|  <D:0148,AX:0015,AY:-0003,AZ:0998>                                                         |
+----------------------------------------------------------------------------------------------+
|  > Test Mode (collapsible)                                                                   |
|  Distance[===] AX[===] AY[===] AZ[===]  [Connect][Disconnect][Loop][Send]                   |
+----------------------------------------------------------------------------------------------+
```

## Data Flow

### Sensor -> Audio Pipeline

```
Serial Input (20fps)
  | "<D:NNNN,AX:NNNN,AY:NNNN,AZ:NNNN>"
  v
SensorMapper (Ruby)
  +- distance_to_note(dist_mm)
  |    +- clamp to dist_min/max
  |    +- apply_curve(ratio, curve_type)  -- Lin/Log/Exp/S
  |    +- map to midi_min/max
  |    +- snap to scale (Penta/Maj/Min/Chrom)
  |    +- + transpose (octave * 12)
  |         -> MIDI note -> freq (Hz)
  |
  +- accel_to_fm_depth(ax, ay, az)
  |    +- apply_curve
  |    +- -> fm_depth (0.0-1.0)
  |
  +- in_range?(dist_mm) -> boolean
  v
Web Audio update (Ruby -> JS.global)
  +- carrier.frequency.setTargetAtTime(freq, now, glide_sec)
  +- fm_mod.gain.setTargetAtTime(fm_depth * scale, now, 0.01)
  +- master.gain.setTargetAtTime(target_gain, now, smooth)
       +- in_range:  target_gain = volume (smoothing = attack)
       +- out_range: target_gain = 0      (smoothing = release)
```

### Main Loop (Stateless)

```ruby
def update(dist_mm, ax, ay, az)
  freq     = @mapper.distance_to_note(dist_mm)
  fm_depth = @mapper.accel_to_fm_depth(ax, ay, az)
  in_range = @mapper.in_range?(dist_mm)

  @adapter.update_freq(freq, @glide_sec)
  @adapter.update_fm_depth(fm_depth)
  @adapter.update_gain(in_range ? @volume : 0.0, in_range ? @attack : @release)
end
```

No `@sounding` flag. Default `master.gain.value = 0`. `setTargetAtTime` handles all transitions.

### Curve Presets

```ruby
def apply_curve(ratio, curve_type)
  case curve_type
  when :linear  then ratio
  when :log     then Math.log(1 + ratio * 9) / Math.log(10)
  when :exp     then (10 ** ratio - 1) / 9.0
  when :s_curve then ratio * ratio * (3 - 2 * ratio)
  end
end
```

### Preset Switching

Treat as momentary out-of-range -> rebuild -> in-range:
1. `update_gain(0.0, @release)` — fade out with release time
2. Rebuild patch (Ruby SynthPatch DSL -> Web Audio nodes)
3. `update_gain(@volume, @attack)` — fade in with attack time

## UI Event Flow

```
HTML Element (onchange/onclick)
  |
  v
Ruby callback (registered via JS.global at init)
  +- Update Ruby internal state
  +- Update Web Audio via JS.global
  +- Update DOM display via JS.global[:document]
```

### Event Mapping

| UI Element | Ruby Handler | Effect |
|---|---|---|
| Node slider (gain, freq, cutoff, Q, amp) | `@patch[:node].set_xxx(val)` | `node.param.setTargetAtTime` |
| Node dropdown (wave, filter type) | `@patch[:node].set_type(val)` | `osc.type = val` |
| Preset button | `@presets.switch(name)` | Fade out -> rebuild -> fade in |
| Scale toggle | `@mapper.set_scale(name)` | Next frame |
| Octave < > | `@transpose += 12` / `-= 12` | Next frame |
| Glide slider | `@glide_sec = val / 1000.0` | Next frame |
| Attack/Release | `@attack = val / 1000.0` | Next frame |
| Curve preset (Lin/Log/Exp/S) | `@mapper.set_curve(:dist, type)` | Next frame + redraw curve |

## Note Display

Mixed notation (music convention):
C, C#, D, Eb, E, F, F#, G, G#, A, Bb, B

With octave number: C#4, Eb5, etc.

## Removed Elements

- Play section (merged into Transport)
- FM Edit section (merged into graph nodes)
- Envelope Decay/Sustain sliders (removed; Attack/Release in Transport)
- Sensor Mapping sliders (replaced by curve presets + graphs)
- Existing Canvas-based Synth Patch Graph (replaced by HTML/CSS node graph)

## Kept Elements

- Serial Monitor (collapsible, below fold, for debugging)
- Test Mode (collapsible, sensor emulation)
- Oscilloscope + Level meter (full width)

## Constraints

| Constraint | Mitigation |
|---|---|
| ruby.wasm DOM ops are synchronous | Minimize DOM updates in 20fps loop (update only on change) |
| Canvas drawing per-frame cost | Oscilloscope via `JS.global.requestAnimationFrame` (Ruby callback); curve canvases redraw on change only |
| Web Serial Chrome-only | Target Chrome macOS 146.0.7680.165+ |
| setTargetAtTime timeConstant | glide_sec=0 is instant, 0.005 default |
| Preset switch audio gap | Fade out (release) -> rebuild -> fade in (attack) |

## Testing Strategy

### t-wada Style TDD

Development follows strict Red-Green-Refactor cycle. Tests written BEFORE implementation.

### Test Layer 1: Ruby Unit Tests (ruby.wasm, Go test style)

**No existing test infrastructure.** Build from scratch.

#### Mini Test Framework (new)

```ruby
# web/src/ruby/test_helper.rb — Go test inspired, minimal
$test_count = 0
$fail_count = 0

def assert_equal(expected, actual, msg = "")
  $test_count += 1
  if expected == actual
    JS.global[:console].log("  PASS: #{msg}")
  else
    $fail_count += 1
    JS.global[:console].error("  FAIL: #{msg} — expected #{expected}, got #{actual}")
  end
end

def assert(val, msg = "")
  assert_equal(true, !!val, msg)
end

def test_summary
  status = $fail_count == 0 ? "ALL PASS" : "#{$fail_count} FAILED"
  JS.global[:console].log("#{$test_count} tests, #{status}")
  JS.global[:document].querySelector("#test-result")[:textContent] = status
end
```

#### Test Runner (new)

```
web/
  test.html                  — ruby.wasm test runner page
  src/ruby/
    test_helper.rb           — assert helpers
    sensor_mapper_test.rb    — SensorMapper unit tests
    serial_test.rb           — Serial parser unit tests
    synth_patch_test.rb      — SynthPatch DSL unit tests
    preset_manager_test.rb   — PresetManager unit tests
    ui_controller_test.rb    — UIController state logic tests
```

`test.html` loads ruby.wasm -> production code -> `_test.rb` files in order.
Results output to `console.log` + DOM `#test-result` element.
Chrome automation (`/web-synth-test` skill) reads console to auto-judge pass/fail.

#### Test Targets

**Phase 0 — existing code (before redesign, regression safety net):**
- SensorMapper: `distance_to_note`, `note_to_freq`, `note_name`, `accel_to_fm_depth`, `in_range?`, `set_scale`
- Serial: frame parsing, edge cases (malformed frames, partial data)
- SynthPatch DSL: node creation, `fm()` connection, `build()` compilation
- PresetManager: preset switching, parameter defaults

**Phase 1+ — new code (TDD, tests first):**
- SensorMapper: `apply_curve`, transpose, mixed note notation
- UIController: state management logic (pure Ruby, no DOM in tests)
- Stateless gain update logic

#### No JS Mock Needed

Pure Ruby classes (SensorMapper, Serial, SynthPatch DSL nodes) have no `JS.global` dependency.
Only `test_helper.rb` uses `JS.global[:console]` for output.
WebAdapter (JS-dependent) is covered by integration tests only.

### Test Layer 2: Chrome Integration Tests (`/web-synth-test` skill)

Update skill FIRST before implementation.

- Ruby VM boot verification
- Init Audio -> AudioContext confirmation
- Preset switching -> node parameter changes
- Test Mode -> sensor input -> note/freq display update
- Octave Up/Down -> note display changes by octave
- Curve preset switching
- **Unit test runner**: open test.html, verify `#test-result` shows "ALL PASS"
- Console error check

### Test-First Workflow

```
1. Build test framework (test_helper.rb + test.html)
2. Write unit tests for existing code (Phase 0, regression net)
3. Update /web-synth-test skill with new integration test cases
4. For each new feature:
   a. Write _test.rb (RED)
   b. Implement minimal code (GREEN)
   c. Refactor
   d. Run /web-synth-test for integration check
5. Repeat
```
