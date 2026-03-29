# Web Synth Graph-Centric UI Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign Chrome web synth UI around an interactive Synth Patch Graph with inline controls, instant pitch response, octave transpose, sensor mapping curves, and stateless gain control — all driven by ruby.wasm.

**Architecture:** HTML for static layout (100vw wide), CSS for styling, JS as minimal glue (ruby.wasm loader only). Ruby controls everything via `require "js"` + `JS.global`: DOM manipulation, Web Audio API, Web Serial, Canvas drawing, all logic and state.

**Tech Stack:** ruby.wasm (CRuby 4.0 @ruby/4.0-wasm-wasi@2.8.1), Web Audio API, Web Serial API, Chrome macOS 146.0.7680.165+

---

## File Map

### New Files

| File | Responsibility |
|------|---------------|
| `web/test.html` | ruby.wasm unit test runner page |
| `web/src/ruby/test_helper.rb` | Go-style mini test framework (assert_equal, assert, test_summary) |
| `web/src/ruby/sensor_mapper_test.rb` | SensorMapper unit tests |
| `web/src/ruby/serial_test.rb` | Serial parser unit tests |
| `web/src/ruby/synth_patch_test.rb` | SynthPatch DSL unit tests |
| `web/src/ruby/preset_manager_test.rb` | PresetManager unit tests |
| `web/src/ruby/ui_controller.rb` | Graph UI rendering + DOM control |
| `web/src/ruby/ui_controller_test.rb` | UIController state logic tests |

### Modified Files

| File | Changes |
|------|---------|
| `web/index.html` | Full UI redesign: new HTML layout, CSS, minimal JS glue |
| `web/src/ruby/sensor_mapper.rb` | Add: apply_curve, transpose, mixed note notation |
| `web/src/ruby/main.rb` | Redesign: stateless update loop, Ruby callback registration |
| `web/src/ruby/synth_patch/web_adapter.rb` | Redesign: direct Web Audio control via JS.global |
| `web/src/ruby/synth_patch/synth_patch.rb` | Simplify: remove Decay/Sustain, keep Attack/Release |
| `web/src/ruby/preset_manager.rb` | Adapt to new WebAdapter interface |
| `.claude/skills/web-synth-test.md` | Update integration test cases |

### Unchanged Files

| File | Reason |
|------|--------|
| `web/src/ruby/serial.rb` | Parser logic unchanged |
| `web/src/ruby/synth_patch/node.rb` | DSL node base unchanged |
| `web/src/ruby/synth_patch/audio_adapter.rb` | Abstract base unchanged |
| `web/src/ruby/synth_patch/fm_op_node.rb` | Node type unchanged |
| `web/src/ruby/synth_patch/osc_node.rb` | Node type unchanged |
| `web/src/ruby/synth_patch/filter_node.rb` | Node type unchanged |
| `web/src/ruby/synth_patch/gain_node.rb` | Node type unchanged |
| `web/src/ruby/synth_patch/mixer_node.rb` | Node type unchanged |

---

## Task 1: Test Framework + test.html Runner

**Files:**
- Create: `web/src/ruby/test_helper.rb`
- Create: `web/test.html`

- [ ] **Step 1: Create test_helper.rb**

```ruby
# web/src/ruby/test_helper.rb
# ruby.wasm用ミニテストフレームワーク（Go test方式）
require "js"

$test_count = 0
$fail_count = 0
$current_group = ""

def group(name)
  $current_group = name
  JS.global[:console].log("== #{name} ==")
end

def assert_equal(expected, actual, msg = "")
  $test_count += 1
  label = $current_group.empty? ? msg : "#{$current_group}: #{msg}"
  if expected == actual
    JS.global[:console].log("  PASS: #{label}")
  else
    $fail_count += 1
    JS.global[:console].error("  FAIL: #{label} — expected #{expected.inspect}, got #{actual.inspect}")
  end
end

def assert(val, msg = "")
  assert_equal(true, !!val, msg)
end

def assert_in_delta(expected, actual, delta = 0.001, msg = "")
  $test_count += 1
  label = $current_group.empty? ? msg : "#{$current_group}: #{msg}"
  if (expected - actual).abs <= delta
    JS.global[:console].log("  PASS: #{label}")
  else
    $fail_count += 1
    JS.global[:console].error("  FAIL: #{label} — expected #{expected} ± #{delta}, got #{actual}")
  end
end

def test_summary
  status = $fail_count == 0 ? "ALL PASS" : "#{$fail_count} FAILED"
  msg = "#{$test_count} tests, #{status}"
  JS.global[:console].log(msg)
  el = JS.global[:document].querySelector("#test-result")
  el[:textContent] = msg if el
  el = JS.global[:document].querySelector("#test-detail")
  el[:textContent] = "#{$test_count - $fail_count} passed, #{$fail_count} failed" if el
end
```

- [ ] **Step 2: Create test.html**

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Web Synth Unit Tests</title>
<style>
body { font-family: monospace; background: #1a1a2e; color: #e0e0e0; padding: 20px; }
#test-result { font-size: 24px; font-weight: bold; margin: 20px 0; }
#test-result.pass { color: #4caf50; }
#test-result.fail { color: #f44336; }
#test-detail { color: #999; }
</style>
</head>
<body>
<h1>Web Synth — Ruby Unit Tests</h1>
<div id="test-result">Running...</div>
<div id="test-detail"></div>
<p>Check browser console for details.</p>

<script src="https://cdn.jsdelivr.net/npm/@ruby/4.0-wasm-wasi@2.8.1/dist/browser.script.iife.js"></script>

<!-- テスト対象コード -->
<script type="text/ruby" src="src/ruby/synth_patch/audio_adapter.rb"></script>
<script type="text/ruby" src="src/ruby/synth_patch/node.rb"></script>
<script type="text/ruby" src="src/ruby/synth_patch/osc_node.rb"></script>
<script type="text/ruby" src="src/ruby/synth_patch/fm_op_node.rb"></script>
<script type="text/ruby" src="src/ruby/synth_patch/filter_node.rb"></script>
<script type="text/ruby" src="src/ruby/synth_patch/gain_node.rb"></script>
<script type="text/ruby" src="src/ruby/synth_patch/mixer_node.rb"></script>
<script type="text/ruby" src="src/ruby/synth_patch/synth_patch.rb"></script>
<script type="text/ruby" src="src/ruby/sensor_mapper.rb"></script>
<script type="text/ruby" src="src/ruby/serial.rb"></script>
<script type="text/ruby" src="src/ruby/preset_manager.rb"></script>

<!-- テストフレームワーク -->
<script type="text/ruby" src="src/ruby/test_helper.rb"></script>

<!-- テストファイル（ここに追加） -->

<!-- テスト実行完了 -->
<script type="text/ruby">
test_summary
el = JS.global[:document].querySelector("#test-result")
if $fail_count == 0
  el[:className] = "pass"
else
  el[:className] = "fail"
end
</script>
</body>
</html>
```

- [ ] **Step 3: Start web server and verify test.html loads**

Run: `rake server:start` (user executes)
Open: `http://localhost:8000/test.html`
Expected: "0 tests, ALL PASS" displayed, no console errors.

- [ ] **Step 4: Commit**

```
git add web/src/ruby/test_helper.rb web/test.html
git commit -m "feat: add ruby.wasm unit test framework and test runner"
```

---

## Task 2: Existing Code Unit Tests — SensorMapper

**Files:**
- Create: `web/src/ruby/sensor_mapper_test.rb`
- Modify: `web/test.html` (add script tag)

- [ ] **Step 1: Write sensor_mapper_test.rb**

```ruby
# web/src/ruby/sensor_mapper_test.rb
# SensorMapper既存機能テスト

group "SensorMapper#initialize"

m = SensorMapper.new
assert_equal 20, m.dist_min, "default dist_min"
assert_equal 900, m.dist_max, "default dist_max"
assert_equal 36, m.midi_min, "default midi_min"
assert_equal 84, m.midi_max, "default midi_max"
assert_equal 500, m.accel_scale, "default accel_scale"

group "SensorMapper#note_to_freq"

m = SensorMapper.new
assert_in_delta(440.0, m.note_to_freq(69), 0.1, "A4 = 440Hz")
assert_in_delta(261.6, m.note_to_freq(60), 0.5, "C4 ≈ 261.6Hz")
assert_in_delta(880.0, m.note_to_freq(81), 0.1, "A5 = 880Hz")

group "SensorMapper#note_name"

m = SensorMapper.new
assert_equal "A4", m.note_name(69), "MIDI 69 = A4"
assert_equal "C4", m.note_name(60), "MIDI 60 = C4"
assert_equal "C2", m.note_name(36), "MIDI 36 = C2"

group "SensorMapper#distance_to_note"

m = SensorMapper.new
m.set_scale(:chromatic)
note_min = m.distance_to_note(20)
note_max = m.distance_to_note(900)
assert_equal 36, note_min, "dist_min → midi_min"
assert_equal 84, note_max, "dist_max → midi_max"

group "SensorMapper#distance_to_note — clamping"

m = SensorMapper.new
m.set_scale(:chromatic)
note_below = m.distance_to_note(0)
note_above = m.distance_to_note(2000)
assert_equal 36, note_below, "below dist_min → midi_min"
assert_equal 84, note_above, "above dist_max → midi_max"

group "SensorMapper#distance_to_note — scale snap"

m = SensorMapper.new
m.set_scale(:pentatonic)
note = m.distance_to_note(460)
scale_degrees = [0, 2, 4, 7, 9]
assert(scale_degrees.include?(note % 12), "pentatonic snap: #{note} mod 12 = #{note % 12}")

group "SensorMapper#accel_to_fm_depth"

m = SensorMapper.new
m.accel_scale = 500
depth_zero = m.accel_to_fm_depth(0, 0, 0)
assert_in_delta(0.0, depth_zero, 0.001, "zero accel → 0.0")
depth_full = m.accel_to_fm_depth(200, 200, 200)
assert(depth_full > 0.0, "nonzero accel → positive depth")
assert(depth_full <= 1.0, "depth clamped to 1.0")

group "SensorMapper#in_range?"

m = SensorMapper.new
assert(m.in_range?(100), "100mm in range")
assert(m.in_range?(20), "20mm in range (boundary)")
assert(m.in_range?(900), "900mm in range (boundary)")
assert(!m.in_range?(19), "19mm out of range")
assert(!m.in_range?(901), "901mm out of range")

group "SensorMapper#set_scale"

m = SensorMapper.new
m.set_scale(:major)
m.set_scale(:minor)
m.set_scale(:pentatonic)
m.set_scale(:chromatic)
assert(true, "all scales accepted")

group "SensorMapper#set_dist_range"

m = SensorMapper.new
m.set_dist_range(50, 500)
assert_equal 50, m.dist_min, "dist_min updated"
assert_equal 500, m.dist_max, "dist_max updated"

group "SensorMapper#set_midi_range"

m = SensorMapper.new
m.set_midi_range(48, 72)
assert_equal 48, m.midi_min, "midi_min updated"
assert_equal 72, m.midi_max, "midi_max updated"
```

- [ ] **Step 2: Add script tag to test.html**

In `web/test.html`, add after the `<!-- テストファイル（ここに追加） -->` comment:

```html
<script type="text/ruby" src="src/ruby/sensor_mapper_test.rb"></script>
```

- [ ] **Step 3: Run tests in browser**

Open: `http://localhost:8000/test.html`
Expected: All tests PASS, check console for details.
If any fail, fix the test to match actual existing behavior (these are characterization tests).

- [ ] **Step 4: Commit**

```
git add web/src/ruby/sensor_mapper_test.rb web/test.html
git commit -m "test: add SensorMapper unit tests for existing behavior"
```

---

## Task 3: Existing Code Unit Tests — Serial

**Files:**
- Create: `web/src/ruby/serial_test.rb`
- Modify: `web/test.html` (add script tag)

- [ ] **Step 1: Write serial_test.rb**

```ruby
# web/src/ruby/serial_test.rb
# Serial既存機能テスト

group "Serial#initialize"

s = Serial.new
assert(!s.connected?, "initially disconnected")
assert_equal 0, s.parse_error_count, "no parse errors initially"

group "Serial#on_connect"

s = Serial.new
s.on_connect(115200)
assert(s.connected?, "connected after on_connect")
assert_equal 115200, s.baud_rate, "baud rate set"

group "Serial#on_disconnect"

s = Serial.new
s.on_connect(115200)
s.on_disconnect
assert(!s.connected?, "disconnected after on_disconnect")

group "Serial#receive — valid frame"

s = Serial.new
s.on_connect(115200)
result = nil
s.receive("<D:0150,AX:0012,AY:-0005,AZ:1002>") do |d, ax, ay, az|
  result = [d, ax, ay, az]
end
assert_equal [150, 12, -5, 1002], result, "parsed valid frame"

group "Serial#receive — partial data"

s = Serial.new
s.on_connect(115200)
result = nil
s.receive("<D:0100,AX") do |d, ax, ay, az|
  result = [d, ax, ay, az]
end
s.receive(",AY:0010,AZ:0500>") do |d, ax, ay, az|
  result = [d, ax, ay, az]
end
# パーシャルデータの挙動は実装依存 — 結果を確認して調整
```

- [ ] **Step 2: Add script tag to test.html**

```html
<script type="text/ruby" src="src/ruby/serial_test.rb"></script>
```

- [ ] **Step 3: Run tests, adjust for actual Serial#receive interface**

Open: `http://localhost:8000/test.html`
The Serial class uses a callback pattern. Read `serial.rb` receive method carefully and adjust the test to match the actual interface (block vs stored callback vs return value).

- [ ] **Step 4: Commit**

```
git add web/src/ruby/serial_test.rb web/test.html
git commit -m "test: add Serial parser unit tests"
```

---

## Task 4: Existing Code Unit Tests — SynthPatch DSL

**Files:**
- Create: `web/src/ruby/synth_patch_test.rb`
- Modify: `web/test.html` (add script tag)

- [ ] **Step 1: Write synth_patch_test.rb**

```ruby
# web/src/ruby/synth_patch_test.rb
# SynthPatch DSL既存機能テスト

group "SynthPatch::Node — id generation"

SynthPatch::Node.reset_id_counter!
n1 = SynthPatch::Node.new
n2 = SynthPatch::Node.new
assert(n1.handle != n2.handle, "unique handles")

group "SynthPatch::FMOpNode"

node = SynthPatch::FMOpNode.new(:triangle, freq: 220, amp: 150, name: :test_mod)
assert_equal :triangle, node.waveform, "waveform"
assert_equal 220, node.freq, "freq"
assert_equal 150, node.amp, "amp"
assert_equal :test_mod, node.name, "name"

spec = node.to_spec_h
assert_equal "fm_op", spec[:type], "spec type"
assert_equal "triangle", spec[:waveform].to_s, "spec waveform"

group "SynthPatch::FilterNode"

node = SynthPatch::FilterNode.new(:lowpass, cutoff: 1200, q: 1.5, name: :test_filter)
assert_equal :lowpass, node.filter_type, "filter_type"
assert_equal 1200, node.cutoff, "cutoff"
assert_equal 1.5, node.q, "q"

group "SynthPatch::GainNode"

node = SynthPatch::GainNode.new(0.4, name: :test_gain)
assert_equal 0.4, node.gain_value, "gain_value"

group "SynthPatch::MixerNode"

input1 = SynthPatch::FMOpNode.new(:sine, freq: 440, name: :i1)
input2 = SynthPatch::FMOpNode.new(:sine, freq: 440, name: :i2)
mixer = SynthPatch::MixerNode.new(input1, input2, name: :mix)
assert_equal 2, mixer.inputs.length, "2 inputs"

group "Node#fm connection"

mod = SynthPatch::FMOpNode.new(:triangle, freq: 220, amp: 150, name: :mod)
carrier = SynthPatch::FMOpNode.new(:triangle, freq: 220, name: :carrier)
carrier.fm(mod)
assert_equal mod, carrier.fm_modulator, "fm modulator set"

group "Node#filter chaining"

node = SynthPatch::FMOpNode.new(:sine, freq: 440, name: :src)
filtered = node.filter(:lowpass, cutoff: 1000, q: 1.0, name: :flt)
assert(filtered.is_a?(SynthPatch::FilterNode), "returns FilterNode")

group "Node#gain chaining"

node = SynthPatch::FMOpNode.new(:sine, freq: 440, name: :src2)
gained = node.gain(0.5, name: :gn)
assert(gained.is_a?(SynthPatch::GainNode), "returns GainNode")

group "SynthPatch ADSR defaults"

defaults = SynthPatch::ADSR_DEFAULTS
assert_equal 0.01, defaults[:attack], "default attack"
assert_equal 0.3, defaults[:decay], "default decay"
assert_equal 0.6, defaults[:sustain], "default sustain"
assert_equal 0.3, defaults[:release], "default release"
```

- [ ] **Step 2: Add script tag to test.html**

```html
<script type="text/ruby" src="src/ruby/synth_patch_test.rb"></script>
```

- [ ] **Step 3: Run tests in browser**

Open: `http://localhost:8000/test.html`
Expected: All PASS. Adjust any mismatches to actual behavior.

- [ ] **Step 4: Commit**

```
git add web/src/ruby/synth_patch_test.rb web/test.html
git commit -m "test: add SynthPatch DSL unit tests"
```

---

## Task 5: Update /web-synth-test Skill

**Files:**
- Modify: `.claude/skills/web-synth-test.md`

- [ ] **Step 1: Read current web-synth-test skill**

Read `.claude/skills/web-synth-test.md` to understand current test steps.

- [ ] **Step 2: Add unit test runner step and new integration cases**

Add to the skill's test sequence:
1. Open `http://localhost:8000/test.html`
2. Wait for Ruby VM boot
3. Read `#test-result` text — must contain "ALL PASS"
4. Read console for any FAIL lines
5. Navigate to `http://localhost:8000/` for integration tests
6. Existing integration tests (Init Audio, preset, etc.)
7. New cases: octave Up/Down, curve preset switching, Glide slider, note display format

- [ ] **Step 3: Commit**

```
git add .claude/skills/web-synth-test.md
git commit -m "test: update web-synth-test skill with unit test runner and new cases"
```

---

## Task 6: SensorMapper — apply_curve

**Files:**
- Modify: `web/src/ruby/sensor_mapper.rb`
- Modify: `web/src/ruby/sensor_mapper_test.rb`

- [ ] **Step 1: Write failing tests for apply_curve**

Append to `web/src/ruby/sensor_mapper_test.rb`:

```ruby
group "SensorMapper#apply_curve — linear"

m = SensorMapper.new
assert_in_delta(0.0, m.apply_curve(0.0, :linear), 0.001, "linear 0.0")
assert_in_delta(0.5, m.apply_curve(0.5, :linear), 0.001, "linear 0.5")
assert_in_delta(1.0, m.apply_curve(1.0, :linear), 0.001, "linear 1.0")

group "SensorMapper#apply_curve — log"

m = SensorMapper.new
assert_in_delta(0.0, m.apply_curve(0.0, :log), 0.001, "log 0.0")
val = m.apply_curve(0.5, :log)
assert(val > 0.5, "log 0.5 > 0.5 (early sensitivity): #{val}")
assert_in_delta(1.0, m.apply_curve(1.0, :log), 0.001, "log 1.0")

group "SensorMapper#apply_curve — exp"

m = SensorMapper.new
assert_in_delta(0.0, m.apply_curve(0.0, :exp), 0.001, "exp 0.0")
val = m.apply_curve(0.5, :exp)
assert(val < 0.5, "exp 0.5 < 0.5 (late sensitivity): #{val}")
assert_in_delta(1.0, m.apply_curve(1.0, :exp), 0.001, "exp 1.0")

group "SensorMapper#apply_curve — s_curve"

m = SensorMapper.new
assert_in_delta(0.0, m.apply_curve(0.0, :s_curve), 0.001, "s_curve 0.0")
assert_in_delta(0.5, m.apply_curve(0.5, :s_curve), 0.001, "s_curve 0.5 = midpoint")
assert_in_delta(1.0, m.apply_curve(1.0, :s_curve), 0.001, "s_curve 1.0")
```

- [ ] **Step 2: Run tests to verify they fail**

Open: `http://localhost:8000/test.html`
Expected: FAIL — `apply_curve` method not defined.

- [ ] **Step 3: Implement apply_curve in sensor_mapper.rb**

Add to `SensorMapper` class in `web/src/ruby/sensor_mapper.rb`:

```ruby
  # カーブプリセット適用
  def apply_curve(ratio, curve_type)
    case curve_type
    when :linear  then ratio
    when :log     then Math.log(1 + ratio * 9) / Math.log(10)
    when :exp     then (10 ** ratio - 1) / 9.0
    when :s_curve then ratio * ratio * (3 - 2 * ratio)
    else ratio
    end
  end
```

- [ ] **Step 4: Run tests to verify they pass**

Open: `http://localhost:8000/test.html`
Expected: All apply_curve tests PASS.

- [ ] **Step 5: Commit**

```
git add web/src/ruby/sensor_mapper.rb web/src/ruby/sensor_mapper_test.rb
git commit -m "feat: add apply_curve with 4 preset types to SensorMapper"
```

---

## Task 7: SensorMapper — Curve Integration + Curve State

**Files:**
- Modify: `web/src/ruby/sensor_mapper.rb`
- Modify: `web/src/ruby/sensor_mapper_test.rb`

- [ ] **Step 1: Write failing tests for curve state and integration**

Append to `web/src/ruby/sensor_mapper_test.rb`:

```ruby
group "SensorMapper — dist_curve / accel_curve state"

m = SensorMapper.new
assert_equal :linear, m.dist_curve, "default dist_curve is linear"
assert_equal :linear, m.accel_curve, "default accel_curve is linear"

m.set_dist_curve(:log)
assert_equal :log, m.dist_curve, "dist_curve updated to log"

m.set_accel_curve(:exp)
assert_equal :exp, m.accel_curve, "accel_curve updated to exp"

group "SensorMapper#distance_to_note — with log curve"

m = SensorMapper.new
m.set_scale(:chromatic)
m.set_dist_curve(:log)
note_linear = SensorMapper.new.tap { |x| x.set_scale(:chromatic) }.distance_to_note(200)
note_log = m.distance_to_note(200)
# log曲線は低距離で感度が高い → 同じ距離でも高めのノート
assert(note_log >= note_linear, "log curve: note_log(#{note_log}) >= note_linear(#{note_linear})")

group "SensorMapper#accel_to_fm_depth — with exp curve"

m = SensorMapper.new
m.accel_scale = 500
m.set_accel_curve(:exp)
depth_exp = m.accel_to_fm_depth(100, 100, 100)
m2 = SensorMapper.new
m2.accel_scale = 500
depth_lin = m2.accel_to_fm_depth(100, 100, 100)
# exp曲線は中域で感度が低い → 同じ加速度でも低めのdepth
assert(depth_exp <= depth_lin, "exp curve: depth_exp(#{depth_exp}) <= depth_lin(#{depth_lin})")
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — `dist_curve`, `accel_curve`, `set_dist_curve`, `set_accel_curve` not defined.

- [ ] **Step 3: Implement curve state in sensor_mapper.rb**

Add to `SensorMapper`:

```ruby
  attr_reader :dist_curve, :accel_curve

  # initializeに追加
  @dist_curve = :linear
  @accel_curve = :linear

  def set_dist_curve(type)
    @dist_curve = type
  end

  def set_accel_curve(type)
    @accel_curve = type
  end
```

Modify `distance_to_note` to apply curve:

```ruby
  def distance_to_note(dist_mm)
    clamped = dist_mm.clamp(@dist_min, @dist_max)
    ratio = (clamped - @dist_min).to_f / (@dist_max - @dist_min)
    curved = apply_curve(ratio, @dist_curve)
    raw_note = @midi_min + (curved * (@midi_max - @midi_min)).round
    # スケールスナップ（既存ロジック維持）
    snap_to_scale(raw_note)
  end
```

Modify `accel_to_fm_depth` to apply curve:

```ruby
  def accel_to_fm_depth(ax, ay, az)
    ratio = ((ax.abs + ay.abs + az.abs).to_f / @accel_scale).clamp(0.0, 1.0)
    apply_curve(ratio, @accel_curve)
  end
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: All PASS.

- [ ] **Step 5: Commit**

```
git add web/src/ruby/sensor_mapper.rb web/src/ruby/sensor_mapper_test.rb
git commit -m "feat: add curve state and integrate into distance/accel mapping"
```

---

## Task 8: SensorMapper — Transpose + Mixed Note Notation

**Files:**
- Modify: `web/src/ruby/sensor_mapper.rb`
- Modify: `web/src/ruby/sensor_mapper_test.rb`

- [ ] **Step 1: Write failing tests for transpose and note_name**

Append to `web/src/ruby/sensor_mapper_test.rb`:

```ruby
group "SensorMapper — transpose"

m = SensorMapper.new
assert_equal 0, m.transpose, "default transpose = 0"

m.transpose_up
assert_equal 12, m.transpose, "transpose_up → +12"

m.transpose_up
assert_equal 24, m.transpose, "transpose_up → +24"

m.transpose_up
assert_equal 24, m.transpose, "transpose_up clamped at +24"

m.transpose_down
assert_equal 12, m.transpose, "transpose_down → +12"

4.times { m.transpose_down }
assert_equal -24, m.transpose, "transpose_down clamped at -24"

group "SensorMapper#distance_to_note — with transpose"

m = SensorMapper.new
m.set_scale(:chromatic)
base_note = m.distance_to_note(460)
m.transpose_up
transposed_note = m.distance_to_note(460)
assert_equal base_note + 12, transposed_note, "transpose +12 applied"

group "SensorMapper#note_name — mixed notation"

m = SensorMapper.new
assert_equal "C4", m.note_name(60), "C4"
assert_equal "C#4", m.note_name(61), "C#4"
assert_equal "D4", m.note_name(62), "D4"
assert_equal "Eb4", m.note_name(63), "Eb4"
assert_equal "E4", m.note_name(64), "E4"
assert_equal "F4", m.note_name(65), "F4"
assert_equal "F#4", m.note_name(66), "F#4"
assert_equal "G4", m.note_name(67), "G4"
assert_equal "G#4", m.note_name(68), "G#4"
assert_equal "A4", m.note_name(69), "A4"
assert_equal "Bb4", m.note_name(70), "Bb4"
assert_equal "B4", m.note_name(71), "B4"
assert_equal "C5", m.note_name(72), "C5"
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — `transpose`, `transpose_up`, `transpose_down` not defined. `note_name` may fail for mixed notation.

- [ ] **Step 3: Implement transpose and update note_name**

Add to `SensorMapper`:

```ruby
  attr_reader :transpose

  # initializeに追加
  @transpose = 0

  # オクターブ転置（±2オクターブ制限）
  def transpose_up
    @transpose = [@transpose + 12, 24].min
  end

  def transpose_down
    @transpose = [@transpose - 12, -24].max
  end
```

Update `distance_to_note` to add transpose after scale snap:

```ruby
  def distance_to_note(dist_mm)
    clamped = dist_mm.clamp(@dist_min, @dist_max)
    ratio = (clamped - @dist_min).to_f / (@dist_max - @dist_min)
    curved = apply_curve(ratio, @dist_curve)
    raw_note = @midi_min + (curved * (@midi_max - @midi_min)).round
    snap_to_scale(raw_note) + @transpose
  end
```

Update `NOTE_NAMES` constant for mixed notation:

```ruby
  NOTE_NAMES = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "G#", "A", "Bb", "B"].freeze
```

Ensure `note_name` method:

```ruby
  def note_name(midi_note)
    octave = (midi_note / 12) - 1
    name = NOTE_NAMES[midi_note % 12]
    "#{name}#{octave}"
  end
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: All PASS.

- [ ] **Step 5: Commit**

```
git add web/src/ruby/sensor_mapper.rb web/src/ruby/sensor_mapper_test.rb
git commit -m "feat: add octave transpose and mixed note notation to SensorMapper"
```

---

## Task 9: SynthPatch — Remove Decay/Sustain, Keep Attack/Release

**Files:**
- Modify: `web/src/ruby/synth_patch/synth_patch.rb`
- Modify: `web/src/ruby/synth_patch_test.rb`

- [ ] **Step 1: Write tests for simplified ADSR**

Append to `web/src/ruby/synth_patch_test.rb`:

```ruby
group "SynthPatch — attack/release only"

# WebAdapter不要のためadapter=nilでビルドしない
patch = SynthPatch.new(nil)
patch.set_attack(0.05)
patch.set_release(0.2)
assert_equal 0.05, patch.attack, "attack set"
assert_equal 0.2, patch.release, "release set"
```

- [ ] **Step 2: Run tests to verify current behavior**

Expected: PASS (attack/release already exist). This is a characterization test before removal.

- [ ] **Step 3: Remove decay/sustain from SynthPatch**

In `web/src/ruby/synth_patch/synth_patch.rb`:
- Remove `decay` and `sustain` from `ADSR_DEFAULTS`
- Remove `attr_reader :decay, :sustain`
- Remove `set_decay` and `set_sustain` methods
- Update `ADSR_DEFAULTS` to: `{ attack: 0.01, release: 0.3 }.freeze`
- Remove decay/sustain from `to_h`, `status`, and any other references

- [ ] **Step 4: Update synth_patch_test.rb to verify removal**

Replace the ADSR defaults test:

```ruby
group "SynthPatch ADSR defaults — attack/release only"

defaults = SynthPatch::ADSR_DEFAULTS
assert_equal 0.01, defaults[:attack], "default attack"
assert_equal 0.3, defaults[:release], "default release"
assert_equal nil, defaults[:decay], "no decay"
assert_equal nil, defaults[:sustain], "no sustain"
```

- [ ] **Step 5: Run tests to verify they pass**

Expected: All PASS.

- [ ] **Step 6: Commit**

```
git add web/src/ruby/synth_patch/synth_patch.rb web/src/ruby/synth_patch_test.rb
git commit -m "refactor: remove decay/sustain from SynthPatch, keep attack/release only"
```

---

## Task 10: WebAdapter — Redesign for Direct Web Audio Control

**Files:**
- Modify: `web/src/ruby/synth_patch/web_adapter.rb`
- Modify: `web/src/ruby/synth_patch/audio_adapter.rb`

- [ ] **Step 1: Redesign audio_adapter.rb interface**

```ruby
# web/src/ruby/synth_patch/audio_adapter.rb
# Web Audio直接制御アダプター基底
class SynthPatch::AudioAdapter
  def build_graph(json_spec)
    raise NotImplementedError
  end

  def update_freq(freq, glide_sec)
    raise NotImplementedError
  end

  def update_fm_depth(depth)
    raise NotImplementedError
  end

  def update_gain(target, smoothing)
    raise NotImplementedError
  end

  def update_param(node_name, param, value)
    raise NotImplementedError
  end
end
```

- [ ] **Step 2: Redesign web_adapter.rb for JS.global direct control**

```ruby
# web/src/ruby/synth_patch/web_adapter.rb
# ruby.wasmからWeb Audio APIを直接操作
require "js"

class SynthPatch::WebAdapter < SynthPatch::AudioAdapter
  def initialize
    @ctx = nil
    @nodes = {}
  end

  def audio_context
    @ctx
  end

  def init_audio
    @ctx = JS.global[:AudioContext].new
    @analyser = @ctx.createAnalyser
    @analyser[:fftSize] = 2048
    @analyser.connect(@ctx[:destination])
  end

  def build_graph(json_spec)
    spec = JSON.parse(json_spec)
    disconnect_all
    build_nodes(spec)
    connect_nodes(spec)
  end

  def update_freq(freq, glide_sec)
    now = @ctx[:currentTime].to_f
    pitch_ids = [:fm_carrier, :fm_mod]
    pitch_ids.each do |id|
      node = @nodes[id]
      next unless node
      osc = node[:osc]
      osc[:frequency].setTargetAtTime(freq.to_f, now, glide_sec.to_f) if osc
    end
  end

  def update_fm_depth(depth)
    now = @ctx[:currentTime].to_f
    node = @nodes[:fm_mod]
    return unless node
    amp = node[:gain]
    amp[:gain].setTargetAtTime(depth.to_f * @fm_depth_scale, now, 0.01) if amp
  end

  def update_gain(target, smoothing)
    now = @ctx[:currentTime].to_f
    node = @nodes[:master]
    return unless node
    gain = node[:gain_node]
    gain[:gain].setTargetAtTime(target.to_f, now, smoothing.to_f) if gain
  end

  def update_param(node_name, param, value)
    node = @nodes[node_name.to_sym]
    return unless node
    now = @ctx[:currentTime].to_f
    case param.to_s
    when "waveform"
      node[:osc][:type] = value.to_s if node[:osc]
    when "cutoff"
      node[:filter][:frequency].setTargetAtTime(value.to_f, now, 0.01) if node[:filter]
    when "q"
      node[:filter][:Q].setTargetAtTime(value.to_f, now, 0.01) if node[:filter]
    when "filter_type"
      node[:filter][:type] = value.to_s if node[:filter]
    when "gain"
      node[:gain_node][:gain].setTargetAtTime(value.to_f, now, 0.01) if node[:gain_node]
    end
  end

  private

  def disconnect_all
    @nodes.each_value do |n|
      n.each_value { |web_node| web_node.disconnect rescue nil if web_node.respond_to?(:disconnect) }
    end
    @nodes = {}
  end

  def build_nodes(spec)
    @fm_depth_scale = 400
    spec["nodes"].each do |name, node_spec|
      @nodes[name.to_sym] = create_web_audio_node(node_spec)
    end
  end

  def create_web_audio_node(spec)
    case spec["type"]
    when "fm_op"
      osc = @ctx.createOscillator
      osc[:type] = spec["waveform"]
      osc[:frequency][:value] = spec["freq"].to_f
      gain = @ctx.createGain
      gain[:gain][:value] = spec["amp"].to_f
      osc.connect(gain)
      osc.start
      { osc: osc, gain: gain }
    when "filter"
      filter = @ctx.createBiquadFilter
      filter[:type] = spec["filter_type"]
      filter[:frequency][:value] = spec["cutoff"].to_f
      filter[:Q][:value] = spec["q"].to_f
      { filter: filter }
    when "gain"
      gain = @ctx.createGain
      gain[:gain][:value] = spec["gain"].to_f
      { gain_node: gain }
    when "mixer"
      gain = @ctx.createGain
      gain[:gain][:value] = 1.0
      { gain_node: gain }
    end
  end

  def connect_nodes(spec)
    # 接続ロジック: spec["connections"]に基づく
    spec["connections"]&.each do |conn|
      from_node = @nodes[conn["from"].to_sym]
      to_node = @nodes[conn["to"].to_sym]
      next unless from_node && to_node
      output = get_output(from_node)
      input = get_input(to_node, conn["target"])
      output.connect(input) if output && input
    end
    # master → analyser
    master = @nodes[:master]
    if master
      get_output(master)&.connect(@analyser)
    end
  end

  def get_output(node)
    node[:gain] || node[:gain_node] || node[:filter] || node[:osc]
  end

  def get_input(node, target = nil)
    if target == "fm"
      node[:osc]&.[](:frequency)
    else
      node[:filter] || node[:gain_node] || node[:osc]
    end
  end
end
```

- [ ] **Step 3: Run existing tests to check nothing breaks**

Open: `http://localhost:8000/test.html`
Expected: All existing tests still PASS (WebAdapter tests are integration-only).

- [ ] **Step 4: Commit**

```
git add web/src/ruby/synth_patch/web_adapter.rb web/src/ruby/synth_patch/audio_adapter.rb
git commit -m "refactor: redesign WebAdapter for direct Web Audio control via JS.global"
```

---

## Task 11: Main Loop — Stateless Update

**Files:**
- Modify: `web/src/ruby/main.rb`

- [ ] **Step 1: Redesign main.rb**

```ruby
# web/src/ruby/main.rb
# アプリケーションメインループ（ステートレス）
require "js"

class SynthApp
  def initialize(serial, mapper, presets)
    @serial = serial
    @mapper = mapper
    @presets = presets
    @adapter = nil
    @glide_sec = 0.005
    @attack = 0.01
    @release = 0.2
    @volume = 0.4
    @transpose = 0
  end

  def init_audio
    @adapter = SynthPatch::WebAdapter.new
    @adapter.init_audio
    @presets.switch(:otamatone)
  end

  def register_callbacks
    doc = JS.global[:document]

    # シリアル接続コールバック
    JS.global[:rubySerialOnConnect] = ->(baud) { on_connect(baud.to_i) }
    JS.global[:rubySerialOnDisconnect] = ->() { on_disconnect }
    JS.global[:rubySerialOnReceive] = ->(data) { on_receive(data.to_s) }

    # UIパラメータ変更コールバック
    JS.global[:rubyOnParam] = ->(key, value) { on_param(key.to_s, value) }

    # Init Audioボタン
    JS.global[:rubyInitAudio] = ->() { init_audio }
  end

  def on_connect(baud)
    @serial.on_connect(baud)
  end

  def on_disconnect
    @serial.on_disconnect
  end

  def on_receive(data)
    @serial.receive(data) do |d, ax, ay, az|
      update(d, ax, ay, az)
    end
  end

  # ステートレス更新 — 毎フレーム同じ処理
  def update(dist_mm, ax, ay, az)
    return unless @adapter

    freq = @mapper.distance_to_note(dist_mm)
    fm_depth = @mapper.accel_to_fm_depth(ax, ay, az)
    in_range = @mapper.in_range?(dist_mm)

    @adapter.update_freq(@mapper.note_to_freq(freq), @glide_sec)
    @adapter.update_fm_depth(fm_depth)
    @adapter.update_gain(in_range ? @volume : 0.0, in_range ? @attack : @release)

    # UI表示更新
    update_display(freq, @mapper.note_to_freq(freq), dist_mm, fm_depth)
  end

  def on_param(key, value)
    case key
    when "preset"    then switch_preset(value.to_s.to_sym)
    when "scale"     then @mapper.set_scale(value.to_s.to_sym)
    when "oct_up"    then @mapper.transpose_up
    when "oct_down"  then @mapper.transpose_down
    when "glide"     then @glide_sec = value.to_f / 1000.0
    when "attack"    then @attack = value.to_f / 1000.0
    when "release"   then @release = value.to_f / 1000.0
    when "dist_curve"  then @mapper.set_dist_curve(value.to_s.to_sym)
    when "accel_curve" then @mapper.set_accel_curve(value.to_s.to_sym)
    else
      # ノードパラメータ (例: "filter:cutoff", "master:gain")
      parts = key.split(":")
      if parts.length == 2
        @presets.patch&.[](parts[0].to_sym)&.set_param(parts[1].to_sym, value.to_f)
        @adapter&.update_param(parts[0], parts[1], value)
      end
    end
  end

  private

  # プリセット切替 — 範囲外→再構築→範囲内と同等
  def switch_preset(name)
    @adapter.update_gain(0.0, @release)
    @presets.switch(name)
    # 短いディレイ後にフェードイン（JSのsetTimeoutで）
    JS.global.setTimeout(-> {
      @adapter.update_gain(@volume, @attack)
    }, (@release * 1000).to_i + 50)
  end

  def update_display(midi_note, freq, dist_mm, fm_depth)
    doc = JS.global[:document]
    el = doc.querySelector("#note-display")
    el[:textContent] = @mapper.note_name(midi_note) if el
    el = doc.querySelector("#freq-display")
    el[:textContent] = "#{freq.round}Hz" if el
    el = doc.querySelector("#dist-display")
    el[:textContent] = "#{dist_mm}mm" if el
  end
end

# グローバル初期化
$serial = Serial.new
$mapper = SensorMapper.new
$presets = PresetManager.new
$app = SynthApp.new($serial, $mapper, $presets)
$app.register_callbacks

JS.global[:console].log("SynthApp initialized")
```

- [ ] **Step 2: Run unit tests to verify no regressions**

Open: `http://localhost:8000/test.html`
Expected: All existing tests PASS (main.rb is not tested by unit tests, only integration).

- [ ] **Step 3: Commit**

```
git add web/src/ruby/main.rb
git commit -m "refactor: redesign main.rb with stateless update loop"
```

---

## Task 12: UIController — Graph UI State + Curve Drawing

**Files:**
- Create: `web/src/ruby/ui_controller.rb`
- Create: `web/src/ruby/ui_controller_test.rb`
- Modify: `web/test.html` (add script tags)

- [ ] **Step 1: Write failing tests for UIController**

```ruby
# web/src/ruby/ui_controller_test.rb
# UIController状態管理テスト（DOM操作はテストしない）

group "UIController — curve data generation"

# カーブ描画用データ生成ロジック
uc = UIController.new

points = uc.curve_points(:linear, 5)
assert_equal 5, points.length, "5 points"
assert_in_delta(0.0, points[0], 0.01, "linear first = 0")
assert_in_delta(1.0, points[4], 0.01, "linear last = 1")

log_points = uc.curve_points(:log, 5)
assert(log_points[2] > points[2], "log midpoint > linear midpoint")

group "UIController — octave indicator"

uc = UIController.new
assert_equal 2, uc.octave_index(0), "transpose 0 → index 2 (center)"
assert_equal 3, uc.octave_index(12), "transpose +12 → index 3"
assert_equal 4, uc.octave_index(24), "transpose +24 → index 4"
assert_equal 1, uc.octave_index(-12), "transpose -12 → index 1"
assert_equal 0, uc.octave_index(-24), "transpose -24 → index 0"
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — UIController not defined.

- [ ] **Step 3: Implement UIController**

```ruby
# web/src/ruby/ui_controller.rb
# グラフUI描画＋状態管理
require "js"

class UIController
  def initialize
    @doc = JS.global[:document] rescue nil
    @mapper = nil
  end

  def set_mapper(mapper)
    @mapper = mapper
  end

  # カーブ描画用データ生成（0.0〜1.0のy値配列）
  def curve_points(curve_type, count)
    return [] if count < 2
    count.times.map do |i|
      ratio = i.to_f / (count - 1)
      @mapper ? @mapper.apply_curve(ratio, curve_type) : apply_curve_standalone(ratio, curve_type)
    end
  end

  # オクターブインジケーターindex（0-4、中央が2）
  def octave_index(transpose)
    (transpose / 12) + 2
  end

  # カーブCanvas描画
  def draw_curve(canvas_id, curve_type)
    return unless @doc
    canvas = @doc.querySelector(canvas_id)
    return unless canvas
    ctx = canvas.getContext("2d")
    w = canvas[:width].to_i
    h = canvas[:height].to_i
    points = curve_points(curve_type, w)

    ctx.clearRect(0, 0, w, h)
    ctx[:strokeStyle] = "#4caf50"
    ctx[:lineWidth] = 2
    ctx.beginPath
    points.each_with_index do |y, x|
      py = h - (y * h)
      x == 0 ? ctx.moveTo(x, py) : ctx.lineTo(x, py)
    end
    ctx.stroke
  end

  # ステータス表示更新
  def update_status(note_name, freq, dist_mm)
    return unless @doc
    set_text("#note-display", note_name)
    set_text("#freq-display", "#{freq}Hz")
    set_text("#dist-display", "#{dist_mm}mm")
  end

  private

  def set_text(selector, text)
    el = @doc.querySelector(selector)
    el[:textContent] = text if el
  end

  # mapperなしでもテスト可能なフォールバック
  def apply_curve_standalone(ratio, curve_type)
    case curve_type
    when :linear  then ratio
    when :log     then Math.log(1 + ratio * 9) / Math.log(10)
    when :exp     then (10 ** ratio - 1) / 9.0
    when :s_curve then ratio * ratio * (3 - 2 * ratio)
    else ratio
    end
  end
end
```

- [ ] **Step 4: Add script tags to test.html**

Add before test files section:
```html
<script type="text/ruby" src="src/ruby/ui_controller.rb"></script>
```

Add in test files section:
```html
<script type="text/ruby" src="src/ruby/ui_controller_test.rb"></script>
```

- [ ] **Step 5: Run tests to verify they pass**

Expected: All PASS.

- [ ] **Step 6: Commit**

```
git add web/src/ruby/ui_controller.rb web/src/ruby/ui_controller_test.rb web/test.html
git commit -m "feat: add UIController with curve data generation and octave indicator"
```

---

## Task 13: index.html — Full UI Redesign (HTML + CSS)

**Files:**
- Modify: `web/index.html`

This is the largest task. It replaces the entire HTML body and CSS with the new graph-centric layout.

- [ ] **Step 1: Replace HTML body with new layout**

Replace the entire `<body>` content in `web/index.html` with the new layout. Key sections:

**Header bar:**
```html
<header id="header">
  <button id="btn-connect">Connect</button>
  <button id="btn-disconnect">Disconnect</button>
  <button id="btn-init-audio">Init Audio</button>
  <span id="serial-status">●</span>
  <span class="spacer"></span>
  <span id="note-display">--</span>
  <span id="freq-display">--</span>
  <span id="dist-display">--</span>
</header>
```

**Synth Patch Graph (HTML/CSS nodes with inline controls):**
```html
<section id="patch-graph">
  <div class="node" id="node-fm-mod">
    <div class="node-title">FM Mod</div>
    <select id="fm-mod-wave"><option>triangle</option><option>sine</option><option>square</option><option>sawtooth</option></select>
    <label>Freq <input type="range" id="fm-mod-freq" min="20" max="2000" value="220"></label>
    <label>Amp <input type="range" id="fm-mod-amp" min="0" max="500" value="150"></label>
  </div>
  <div class="arrow arrow-fm">FM →</div>
  <div class="node" id="node-fm-carrier">
    <div class="node-title">FM Carrier</div>
    <select id="fm-carrier-wave"><option>triangle</option><option>sine</option><option>square</option><option>sawtooth</option></select>
  </div>
  <div class="arrow">→</div>
  <div class="node" id="node-mixer">
    <div class="node-title">Mixer</div>
    <label>Gain <input type="range" id="mixer-gain" min="0" max="100" value="100"></label>
  </div>
  <div class="arrow">→</div>
  <div class="node" id="node-filter">
    <div class="node-title">Filter</div>
    <select id="filter-type"><option>lowpass</option><option>highpass</option><option>bandpass</option></select>
    <label>Cutoff <input type="range" id="filter-cutoff" min="20" max="8000" value="1200"></label>
    <label>Q <input type="range" id="filter-q" min="0.1" max="20" value="1.5" step="0.1"></label>
  </div>
  <div class="arrow">↓</div>
  <div class="node" id="node-master">
    <div class="node-title">Master</div>
    <label>Gain <input type="range" id="master-gain" min="0" max="100" value="40"></label>
    <span>🔊</span>
  </div>
</section>
```

**Sensor Mapping + Transport (2-column):**
```html
<section id="mid-panel">
  <div id="sensor-curves">
    <h3>Sensor Mapping Curves</h3>
    <div class="curve-group">
      <span>Dist → Pitch</span>
      <div class="curve-buttons" id="dist-curve-buttons">
        <button data-curve="linear" class="active">Lin</button>
        <button data-curve="log">Log</button>
        <button data-curve="exp">Exp</button>
        <button data-curve="s_curve">S</button>
      </div>
      <canvas id="dist-curve-canvas" width="200" height="80"></canvas>
    </div>
    <div class="curve-group">
      <span>Accel → FM Depth</span>
      <div class="curve-buttons" id="accel-curve-buttons">
        <button data-curve="linear" class="active">Lin</button>
        <button data-curve="log">Log</button>
        <button data-curve="exp">Exp</button>
        <button data-curve="s_curve">S</button>
      </div>
      <canvas id="accel-curve-canvas" width="200" height="80"></canvas>
    </div>
  </div>
  <div id="transport">
    <div id="presets">
      <button data-preset="otamatone" class="active">Otamatone</button>
      <button data-preset="clean">Clean</button>
      <button data-preset="acid">Acid</button>
      <button data-preset="retro">Retro</button>
    </div>
    <div id="scale-select">
      <button data-scale="pentatonic" class="active">Penta</button>
      <button data-scale="major">Maj</button>
      <button data-scale="minor">Min</button>
      <button data-scale="chromatic">Chrom</button>
    </div>
    <div id="octave-control">
      <button id="oct-down">◀</button>
      <span id="oct-indicators">
        <span class="oct-dot">·</span>
        <span class="oct-dot">·</span>
        <span class="oct-dot active">●</span>
        <span class="oct-dot">·</span>
        <span class="oct-dot">·</span>
      </span>
      <button id="oct-up">▶</button>
    </div>
    <div id="transport-sliders">
      <label>Glide <input type="range" id="glide" min="0" max="50" value="5"> <span id="glide-val">5ms</span></label>
      <label>Attack <input type="range" id="attack" min="1" max="2000" value="10"> <span id="attack-val">10ms</span></label>
      <label>Release <input type="range" id="release" min="10" max="5000" value="200"> <span id="release-val">200ms</span></label>
    </div>
  </div>
</section>
```

**Audio Monitor (full width):**
```html
<section id="audio-monitor">
  <canvas id="oscilloscope"></canvas>
  <canvas id="level-meter"></canvas>
</section>
```

**Serial Monitor (collapsible):**
```html
<details id="serial-monitor">
  <summary>Serial Monitor</summary>
  <div id="serial-log"></div>
</details>
```

**Test Mode (collapsible):**
```html
<details id="test-mode">
  <summary>Test Mode</summary>
  <div id="test-controls">
    <label>Distance <input type="range" id="test-dist" min="0" max="1000" value="500"></label>
    <label>AX <input type="range" id="test-ax" min="-2000" max="2000" value="0"></label>
    <label>AY <input type="range" id="test-ay" min="-2000" max="2000" value="0"></label>
    <label>AZ <input type="range" id="test-az" min="-2000" max="2000" value="1000"></label>
    <button id="test-send">Send</button>
    <button id="test-loop">Loop</button>
  </div>
</details>
```

- [ ] **Step 2: Add CSS for new layout**

```css
* { margin: 0; padding: 0; box-sizing: border-box; }
body { background: #1a1a2e; color: #e0e0e0; font-family: monospace; width: 100vw; overflow-x: hidden; }

#header { display: flex; align-items: center; gap: 8px; padding: 8px 16px; background: #16213e; }
#header .spacer { flex: 1; }
#header button { padding: 4px 12px; background: #0f3460; color: #e0e0e0; border: 1px solid #444; cursor: pointer; }
#header span { font-size: 14px; }
#note-display { font-size: 20px; font-weight: bold; color: #4caf50; min-width: 60px; }
#freq-display { min-width: 80px; }
#dist-display { min-width: 60px; }

#patch-graph { display: flex; flex-wrap: wrap; align-items: flex-start; justify-content: center; gap: 12px; padding: 16px; }
.node { background: #16213e; border: 1px solid #444; border-radius: 8px; padding: 8px 12px; min-width: 140px; }
.node-title { font-weight: bold; font-size: 12px; color: #4caf50; margin-bottom: 4px; text-transform: uppercase; }
.node select, .node input[type="range"] { width: 100%; margin: 2px 0; }
.node label { display: block; font-size: 11px; color: #999; }
.arrow { display: flex; align-items: center; color: #4caf50; font-size: 18px; font-weight: bold; }
.arrow-fm { color: #6644cc; }

#mid-panel { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; padding: 16px; }
#sensor-curves h3 { font-size: 13px; color: #999; margin-bottom: 8px; }
.curve-group { margin-bottom: 12px; }
.curve-group span { font-size: 12px; color: #ccc; }
.curve-buttons { display: flex; gap: 4px; margin: 4px 0; }
.curve-buttons button { padding: 2px 8px; font-size: 11px; background: #0f3460; color: #e0e0e0; border: 1px solid #444; cursor: pointer; }
.curve-buttons button.active { background: #4caf50; color: #1a1a2e; }

#transport { display: flex; flex-direction: column; gap: 8px; }
#presets, #scale-select { display: flex; gap: 4px; }
#presets button, #scale-select button { padding: 4px 12px; background: #0f3460; color: #e0e0e0; border: 1px solid #444; cursor: pointer; }
#presets button.active, #scale-select button.active { background: #4caf50; color: #1a1a2e; }
#octave-control { display: flex; align-items: center; gap: 8px; }
#oct-indicators { display: flex; gap: 4px; font-size: 16px; }
.oct-dot { color: #444; }
.oct-dot.active { color: #4caf50; }
#transport-sliders label { display: flex; align-items: center; gap: 8px; font-size: 12px; }
#transport-sliders input[type="range"] { flex: 1; }

#audio-monitor { display: flex; gap: 8px; padding: 8px 16px; }
#oscilloscope { flex: 3; height: 80px; background: #0a0a1a; border: 1px solid #333; }
#level-meter { flex: 1; height: 80px; background: #0a0a1a; border: 1px solid #333; }

details { padding: 4px 16px; }
details summary { cursor: pointer; font-size: 12px; color: #999; }
#serial-log { max-height: 120px; overflow-y: auto; font-size: 11px; color: #666; white-space: pre; }
#test-controls { display: flex; flex-wrap: wrap; gap: 8px; padding: 8px 0; }
#test-controls label { display: flex; align-items: center; gap: 4px; font-size: 12px; }
#test-controls input[type="range"] { width: 120px; }
```

- [ ] **Step 3: Replace JS with minimal glue code**

```html
<script src="https://cdn.jsdelivr.net/npm/@ruby/4.0-wasm-wasi@2.8.1/dist/browser.script.iife.js"></script>

<!-- Ruby sources -->
<script type="text/ruby" src="src/ruby/synth_patch/audio_adapter.rb"></script>
<script type="text/ruby" src="src/ruby/synth_patch/node.rb"></script>
<script type="text/ruby" src="src/ruby/synth_patch/osc_node.rb"></script>
<script type="text/ruby" src="src/ruby/synth_patch/fm_op_node.rb"></script>
<script type="text/ruby" src="src/ruby/synth_patch/filter_node.rb"></script>
<script type="text/ruby" src="src/ruby/synth_patch/gain_node.rb"></script>
<script type="text/ruby" src="src/ruby/synth_patch/mixer_node.rb"></script>
<script type="text/ruby" src="src/ruby/synth_patch/synth_patch.rb"></script>
<script type="text/ruby" src="src/ruby/synth_patch/web_adapter.rb"></script>
<script type="text/ruby" src="src/ruby/serial.rb"></script>
<script type="text/ruby" src="src/ruby/sensor_mapper.rb"></script>
<script type="text/ruby" src="src/ruby/preset_manager.rb"></script>
<script type="text/ruby" src="src/ruby/ui_controller.rb"></script>
<script type="text/ruby" src="src/ruby/main.rb"></script>

<script>
// グルーコード: Web Serial接続（ruby.wasmからは直接制御が複雑なため）
let serialPort = null;
let serialReader = null;

document.getElementById('btn-connect').addEventListener('click', async () => {
  try {
    serialPort = await navigator.serial.requestPort();
    await serialPort.open({ baudRate: 115200 });
    const decoder = new TextDecoderStream();
    serialPort.readable.pipeTo(decoder.writable);
    serialReader = decoder.readable.getReader();
    if (window.rubySerialOnConnect) window.rubySerialOnConnect(115200);
    readLoop();
  } catch (e) { console.error('Serial connect error:', e); }
});

document.getElementById('btn-disconnect').addEventListener('click', async () => {
  if (serialReader) { await serialReader.cancel(); serialReader = null; }
  if (serialPort) { await serialPort.close(); serialPort = null; }
  if (window.rubySerialOnDisconnect) window.rubySerialOnDisconnect();
});

async function readLoop() {
  while (serialReader) {
    try {
      const { value, done } = await serialReader.read();
      if (done) break;
      if (value && window.rubySerialOnReceive) window.rubySerialOnReceive(value);
    } catch (e) { break; }
  }
}

document.getElementById('btn-init-audio').addEventListener('click', () => {
  if (window.rubyInitAudio) window.rubyInitAudio();
});
</script>
```

- [ ] **Step 4: Run test.html to verify unit tests still pass**

Open: `http://localhost:8000/test.html`
Expected: All unit tests PASS.

- [ ] **Step 5: Manual visual check**

Open: `http://localhost:8000/`
Expected: New layout renders. Nodes visible with inline controls. No JS errors in console.

- [ ] **Step 6: Commit**

```
git add web/index.html
git commit -m "feat: redesign index.html with graph-centric UI layout"
```

---

## Task 14: PresetManager — Adapt to New WebAdapter

**Files:**
- Modify: `web/src/ruby/preset_manager.rb`

- [ ] **Step 1: Update PresetManager to work with new WebAdapter**

The preset definitions use `SynthPatch.build(adapter: WebAdapter.new)`. Since WebAdapter now manages its own audio context, PresetManager needs to accept the adapter externally.

```ruby
# web/src/ruby/preset_manager.rb
# プリセット管理
class PresetManager
  PRESETS = [:otamatone, :clean, :acid, :retro].freeze

  attr_reader :current, :patch

  def initialize
    @current = nil
    @patch = nil
    @adapter = nil
  end

  def set_adapter(adapter)
    @adapter = adapter
  end

  def switch(name)
    return unless PRESETS.include?(name) && @adapter
    @current = name
    @patch = send("build_#{name}")
    @patch
  end

  private

  def build_otamatone
    SynthPatch.build(adapter: @adapter) do |syn|
      mod     = syn.fm_op(:triangle, freq: 220, amp: 150, name: :fm_mod)
      carrier = syn.fm_op(:triangle, freq: 220, name: :fm_carrier)
      carrier.fm(mod)
      syn.mix(carrier, name: :mixer)
         .filter(:lowpass, cutoff: 1200, q: 1.5, name: :filter)
         .gain(0.4, name: :master)
         .out
    end
  end

  def build_clean
    SynthPatch.build(adapter: @adapter) do |syn|
      mod     = syn.fm_op(:sine, freq: 220, amp: 0, name: :fm_mod)
      carrier = syn.fm_op(:sine, freq: 220, name: :fm_carrier)
      carrier.fm(mod)
      syn.mix(carrier, name: :mixer)
         .filter(:lowpass, cutoff: 4000, q: 0.7, name: :filter)
         .gain(0.4, name: :master)
         .out
    end
  end

  def build_acid
    SynthPatch.build(adapter: @adapter) do |syn|
      mod     = syn.fm_op(:sine, freq: 220, amp: 300, name: :fm_mod)
      carrier = syn.fm_op(:sawtooth, freq: 220, name: :fm_carrier)
      carrier.fm(mod)
      syn.mix(carrier, name: :mixer)
         .filter(:lowpass, cutoff: 600, q: 8.0, name: :filter)
         .gain(0.4, name: :master)
         .out
    end
  end

  def build_retro
    SynthPatch.build(adapter: @adapter) do |syn|
      mod     = syn.fm_op(:square, freq: 220, amp: 80, name: :fm_mod)
      carrier = syn.fm_op(:square, freq: 220, name: :fm_carrier)
      carrier.fm(mod)
      syn.mix(carrier, name: :mixer)
         .filter(:lowpass, cutoff: 2000, q: 1.0, name: :filter)
         .gain(0.4, name: :master)
         .out
    end
  end
end
```

- [ ] **Step 2: Update main.rb init_audio to pass adapter**

In `main.rb` `init_audio` method, add:
```ruby
  def init_audio
    @adapter = SynthPatch::WebAdapter.new
    @adapter.init_audio
    @presets.set_adapter(@adapter)
    @presets.switch(:otamatone)
  end
```

- [ ] **Step 3: Run tests**

Expected: All unit tests PASS. PresetManager tests may need adjustment if they test `switch` without adapter.

- [ ] **Step 4: Commit**

```
git add web/src/ruby/preset_manager.rb web/src/ruby/main.rb
git commit -m "refactor: adapt PresetManager to accept external WebAdapter"
```

---

## Task 15: Ruby Event Binding — Connect UI to Ruby Callbacks

**Files:**
- Modify: `web/src/ruby/main.rb`

- [ ] **Step 1: Add DOM event registration in register_callbacks**

Add to `register_callbacks` method in main.rb — register all UI element events from Ruby side:

```ruby
  def register_callbacks
    doc = JS.global[:document]

    # シリアル/Audio コールバック（JSグルーコードから呼ばれる）
    JS.global[:rubySerialOnConnect] = ->(baud) { on_connect(baud.to_i) }
    JS.global[:rubySerialOnDisconnect] = ->() { on_disconnect }
    JS.global[:rubySerialOnReceive] = ->(data) { on_receive(data.to_s) }
    JS.global[:rubyInitAudio] = ->() { init_audio }

    # プリセットボタン
    doc.querySelectorAll("#presets button").forEach do |btn|
      btn.addEventListener("click") do |e|
        name = e[:target].getAttribute("data-preset").to_s
        on_param("preset", name)
        activate_button("#presets button", e[:target])
      end
    end

    # スケールボタン
    doc.querySelectorAll("#scale-select button").forEach do |btn|
      btn.addEventListener("click") do |e|
        name = e[:target].getAttribute("data-scale").to_s
        on_param("scale", name)
        activate_button("#scale-select button", e[:target])
      end
    end

    # オクターブ
    doc.querySelector("#oct-up").addEventListener("click") { on_param("oct_up", nil) ; update_octave_display }
    doc.querySelector("#oct-down").addEventListener("click") { on_param("oct_down", nil) ; update_octave_display }

    # Glide / Attack / Release スライダー
    %w[glide attack release].each do |param|
      el = doc.querySelector("##{param}")
      el.addEventListener("input") do |e|
        val = e[:target][:value].to_f
        on_param(param, val)
        doc.querySelector("##{param}-val")[:textContent] = "#{val.to_i}ms"
      end
    end

    # カーブボタン
    register_curve_buttons("dist", "#dist-curve-buttons", "#dist-curve-canvas")
    register_curve_buttons("accel", "#accel-curve-buttons", "#accel-curve-canvas")

    # ノードパラメータスライダー
    register_node_controls
  end

  private

  def activate_button(group_selector, active_btn)
    doc = JS.global[:document]
    doc.querySelectorAll(group_selector).forEach { |b| b[:classList].remove("active") }
    active_btn[:classList].add("active")
  end

  def update_octave_display
    doc = JS.global[:document]
    dots = doc.querySelectorAll(".oct-dot")
    idx = @ui.octave_index(@mapper.transpose)
    dots.forEach_with_index do |dot, i|
      if i == idx
        dot[:textContent] = "●"
        dot[:classList].add("active")
      else
        dot[:textContent] = "·"
        dot[:classList].remove("active")
      end
    end
  end

  def register_curve_buttons(prefix, buttons_selector, canvas_selector)
    doc = JS.global[:document]
    doc.querySelectorAll("#{buttons_selector} button").forEach do |btn|
      btn.addEventListener("click") do |e|
        curve = e[:target].getAttribute("data-curve").to_s
        on_param("#{prefix}_curve", curve)
        activate_button("#{buttons_selector} button", e[:target])
        @ui.draw_curve(canvas_selector, curve.to_sym)
      end
    end
  end

  def register_node_controls
    doc = JS.global[:document]
    node_params = {
      "fm-mod-wave"    => "fm_mod:waveform",
      "fm-mod-freq"    => "fm_mod:freq",
      "fm-mod-amp"     => "fm_mod:amp",
      "fm-carrier-wave" => "fm_carrier:waveform",
      "mixer-gain"     => "mixer:gain",
      "filter-type"    => "filter:filter_type",
      "filter-cutoff"  => "filter:cutoff",
      "filter-q"       => "filter:q",
      "master-gain"    => "master:gain",
    }
    node_params.each do |el_id, param_key|
      el = doc.querySelector("##{el_id}")
      next unless el
      event = el[:tagName].to_s == "SELECT" ? "change" : "input"
      el.addEventListener(event) do |e|
        on_param(param_key, e[:target][:value])
      end
    end
  end
```

- [ ] **Step 2: Add UIController to SynthApp initialization**

In `SynthApp#initialize`:
```ruby
    @ui = UIController.new
    @ui.set_mapper(@mapper)
```

- [ ] **Step 3: Run test.html, then manual check on index.html**

test.html: All unit tests PASS.
index.html: Click preset buttons, scale buttons, octave — verify console shows parameter changes.

- [ ] **Step 4: Commit**

```
git add web/src/ruby/main.rb
git commit -m "feat: bind all UI events to Ruby callbacks"
```

---

## Task 16: Oscilloscope + Level Meter (Ruby-driven Canvas)

**Files:**
- Modify: `web/src/ruby/ui_controller.rb`
- Modify: `web/src/ruby/main.rb`

- [ ] **Step 1: Add oscilloscope and level meter drawing to UIController**

```ruby
  # UIController に追加

  # オシロスコープ描画（AnalyserNode経由）
  def draw_oscilloscope(analyser)
    return unless @doc && analyser
    canvas = @doc.querySelector("#oscilloscope")
    return unless canvas
    ctx = canvas.getContext("2d")
    w = canvas[:width].to_i
    h = canvas[:height].to_i

    buf_len = analyser[:frequencyBinCount].to_i
    data = JS.global[:Uint8Array].new(buf_len)
    analyser.getByteTimeDomainData(data)

    ctx.clearRect(0, 0, w, h)
    ctx[:strokeStyle] = "#4caf50"
    ctx[:lineWidth] = 1
    ctx.beginPath

    slice_w = w.to_f / buf_len
    buf_len.times do |i|
      v = data[i].to_f / 128.0
      y = v * h / 2.0
      i == 0 ? ctx.moveTo(0, y) : ctx.lineTo(i * slice_w, y)
    end
    ctx.stroke
  end

  # レベルメーター描画
  def draw_level_meter(analyser)
    return unless @doc && analyser
    canvas = @doc.querySelector("#level-meter")
    return unless canvas
    ctx = canvas.getContext("2d")
    w = canvas[:width].to_i
    h = canvas[:height].to_i

    buf_len = analyser[:frequencyBinCount].to_i
    data = JS.global[:Uint8Array].new(buf_len)
    analyser.getByteTimeDomainData(data)

    # RMS計算
    sum = 0.0
    buf_len.times { |i| v = (data[i].to_f - 128) / 128.0; sum += v * v }
    rms = Math.sqrt(sum / buf_len)
    level = (rms * 2).clamp(0.0, 1.0)

    ctx.clearRect(0, 0, w, h)
    bar_w = (level * w).to_i
    ctx[:fillStyle] = level > 0.8 ? "#f44336" : "#4caf50"
    ctx.fillRect(0, 0, bar_w, h)
  end

  # アニメーションループ開始
  def start_animation(analyser)
    @analyser = analyser
    animate_frame
  end

  def animate_frame
    return unless @analyser
    draw_oscilloscope(@analyser)
    draw_level_meter(@analyser)
    JS.global.requestAnimationFrame(->(_) { animate_frame })
  end
```

- [ ] **Step 2: Connect animation in main.rb init_audio**

Add after `@presets.switch(:otamatone)`:
```ruby
    @ui.start_animation(@adapter.analyser)
```

Add `attr_reader :analyser` to WebAdapter (expose the analyser node).

- [ ] **Step 3: Manual check**

Open: `http://localhost:8000/`
Init Audio → verify oscilloscope and level meter animate.

- [ ] **Step 4: Commit**

```
git add web/src/ruby/ui_controller.rb web/src/ruby/main.rb web/src/ruby/synth_patch/web_adapter.rb
git commit -m "feat: add Ruby-driven oscilloscope and level meter animation"
```

---

## Task 17: Serial Monitor + Test Mode

**Files:**
- Modify: `web/src/ruby/main.rb`

- [ ] **Step 1: Add serial log output to on_receive**

In `main.rb`, update `on_receive` to append to serial log:

```ruby
  def on_receive(data)
    @serial.receive(data) do |d, ax, ay, az|
      update(d, ax, ay, az)
    end
    # Serial Monitor表示
    log_el = JS.global[:document].querySelector("#serial-log")
    if log_el
      log_el[:textContent] = log_el[:textContent].to_s + data
      # 最大行数制限
      lines = log_el[:textContent].to_s.split("\n")
      if lines.length > 50
        log_el[:textContent] = lines[-50..].join("\n")
      end
      log_el[:scrollTop] = log_el[:scrollHeight]
    end
  end
```

- [ ] **Step 2: Add Test Mode event binding**

In `register_callbacks`:

```ruby
    # Test Mode
    doc.querySelector("#test-send")&.addEventListener("click") do
      d  = doc.querySelector("#test-dist")[:value].to_i
      ax = doc.querySelector("#test-ax")[:value].to_i
      ay = doc.querySelector("#test-ay")[:value].to_i
      az = doc.querySelector("#test-az")[:value].to_i
      update(d, ax, ay, az)
    end

    @test_loop_id = nil
    doc.querySelector("#test-loop")&.addEventListener("click") do
      if @test_loop_id
        JS.global.clearInterval(@test_loop_id)
        @test_loop_id = nil
      else
        @test_loop_id = JS.global.setInterval(-> {
          d  = doc.querySelector("#test-dist")[:value].to_i
          ax = doc.querySelector("#test-ax")[:value].to_i
          ay = doc.querySelector("#test-ay")[:value].to_i
          az = doc.querySelector("#test-az")[:value].to_i
          update(d, ax, ay, az)
        }, 50)
      end
    end
```

- [ ] **Step 3: Manual check with Test Mode**

Open: `http://localhost:8000/`
Init Audio → open Test Mode → adjust Distance slider → click Loop → verify sound and display update.

- [ ] **Step 4: Commit**

```
git add web/src/ruby/main.rb
git commit -m "feat: add serial monitor output and test mode event binding"
```

---

## Task 18: Initial Curve Canvas Drawing

**Files:**
- Modify: `web/src/ruby/main.rb`

- [ ] **Step 1: Draw initial curves on page load**

Add to end of `register_callbacks`:

```ruby
    # 初期カーブ描画
    @ui.draw_curve("#dist-curve-canvas", :linear)
    @ui.draw_curve("#accel-curve-canvas", :linear)
```

- [ ] **Step 2: Manual check**

Open: `http://localhost:8000/`
Expected: Both curve canvases show linear (diagonal) line on load.

- [ ] **Step 3: Commit**

```
git add web/src/ruby/main.rb
git commit -m "feat: draw initial sensor mapping curves on page load"
```

---

## Task 19: Integration Test Run

- [ ] **Step 1: Run /web-synth-test**

Execute the updated integration test skill. Verify:
1. test.html → "ALL PASS"
2. index.html → Ruby VM boots
3. Init Audio works
4. Preset switching works
5. Test Mode → note/freq display updates
6. Octave Up/Down changes display
7. No console errors

- [ ] **Step 2: Fix any failures found**

Address issues discovered by the integration test.

- [ ] **Step 3: Commit fixes if any**

```
git add -u
git commit -m "fix: address integration test failures"
```

---

## Task 20: Final Cleanup

- [ ] **Step 1: Remove unused JS functions from index.html**

Verify and remove any remaining JS functions that were migrated to Ruby:
- `synthPatchBuild`, `synthPatchNoteOn`, `synthPatchNoteOff`
- `drawPatchGraph`, `updateSensorDisplay`
- Any `oninput`/`onchange` inline handlers
- Unused global variables (`sp`, `_prevActive`, `PRESET_WAVES`, etc.)

- [ ] **Step 2: Run all tests one final time**

test.html: All PASS
/web-synth-test: All integration checks pass

- [ ] **Step 3: Commit**

```
git add web/index.html
git commit -m "chore: remove unused JS functions after Ruby migration"
```
