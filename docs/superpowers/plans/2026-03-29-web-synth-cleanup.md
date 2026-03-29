# Web Synth Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove dead JS code, unify all control through Ruby, add preset UI sync, rewrite web/CLAUDE.md.

**Architecture:** JS is Web Serial async glue only. Ruby controls Web Audio, DOM, Canvas, state. One-way data flow: Serial → Ruby parse → SensorMapper/WebAdapter/UIController.

**Tech Stack:** ruby.wasm (CRuby 4.0 @ruby/4.0-wasm-wasi@2.8.1), Web Audio API, Chrome macOS 146.0.7680.165+

---

## File Map

### Modified Files

| File | Changes |
|------|---------|
| `web/index.html` | Delete ~130 lines of dead JS (synthPatchBuild, updateSensorParams, etc.) |
| `web/src/ruby/main.rb` | Remove JS compat wrappers, add sync_preset_ui, direct DOM serial updates |
| `web/CLAUDE.md` | Full rewrite to match new architecture |

### Unchanged Files

| File | Reason |
|------|--------|
| `web/src/ruby/sensor_mapper.rb` | Pure Ruby, no JS dependency |
| `web/src/ruby/serial.rb` | Pure Ruby, no JS dependency |
| `web/src/ruby/ui_controller.rb` | Already uses JS.global directly |
| `web/src/ruby/synth_patch/*.rb` | DSL unchanged |
| `web/src/ruby/preset_manager.rb` | Already adapted |
| `web/src/ruby/synth_patch/web_adapter.rb` | Already uses JS.global directly |
| `web/test.html` | Cache buster update only |
| `web/src/ruby/*_test.rb` | No changes needed |

---

## Task 1: Delete Dead JS — synthPatchBuild + synthPatchUpdateParam

**Files:**
- Modify: `web/index.html:676-769`

- [ ] **Step 1: Delete dead JS functions**

In `web/index.html`, delete lines 676-769 entirely. This removes:
- `let audioContext;` declaration (line 679)
- `let analyser, analyserData;` declaration (line 680)
- `const sp = { ... };` object (line 681)
- `let _prevActive = false;` (line 682)
- `function ensureAnalyser(outputNode)` (lines 684-695)
- `window.synthPatchBuild = function(json)` (lines 697-759)
- `window.synthPatchUpdateParam = function(name, param, val)` (lines 761-769)

- [ ] **Step 2: Delete updateSensorParams + global state**

Delete lines 771-803:
- `window.updateSensorParams = function(freq, fmDepth, active)` (lines 772-796)
- `window.synthMasterGain = 0.4;` and all 5 global variables (lines 798-803)

- [ ] **Step 3: Delete updateSensorDisplay JS function**

Delete lines 808-815:
- `window.updateSensorDisplay = function(d, ax, ay, az, f, fm, note)` — Ruby `set_text` handles this directly now

- [ ] **Step 4: Delete updateSerialStatus + updateSerialMonitor JS functions**

Delete lines 817-831:
- `window.updateSerialStatus = function(msg, errCount)` (lines 817-821)
- `window.updateSerialMonitor = function(line)` (lines 823-825)
- `function appendSerialMonitor(line)` (lines 827-831) — will be replaced by Ruby

- [ ] **Step 5: Update cache busters**

Change all `?v=20260329f` to `?v=20260329g` in `web/index.html` and `web/test.html`.

- [ ] **Step 6: Verify test.html still passes**

Open `http://localhost:8000/test.html?v=20260329g` in Chrome.
Expected: 127 tests, ALL PASS (JS deletions don't affect Ruby unit tests).

- [ ] **Step 7: Commit**

```
git add web/index.html web/test.html
git commit -m "refactor: delete dead JS functions (synthPatchBuild, updateSensorParams, etc.)"
```

---

## Task 2: Remove JS Compat Wrappers from main.rb

**Files:**
- Modify: `web/src/ruby/main.rb`

- [ ] **Step 1: Replace update_sensor_display — remove JS.global.updateSensorDisplay call**

Replace the entire `update_sensor_display` method (lines 144-154):

```ruby
  # センサーUI更新
  def update_sensor_display(dist, ax, ay, az, freq, fm_depth, note_str)
    set_text("#note-display", note_str)
    set_text("#freq-display", "#{freq}Hz")
    set_text("#dist-display", "#{dist}mm")
  end
```

This removes the `JS.global[:updateSensorDisplay]` compat wrapper (lines 149-153).

- [ ] **Step 2: Replace update_serial_status — direct DOM update**

Replace the `update_serial_status` method (lines 166-172):

```ruby
  # シリアル状態表示
  def update_serial_status(msg, err_count)
    connected = msg.include?("connected at")
    el = JS.global[:document].querySelector("#serial-status")
    begin
      el[:style][:color] = connected ? "#4caf50" : "#f44336"
    rescue JS::Error
    end
  end
```

- [ ] **Step 3: Replace update_serial_monitor — direct DOM update**

Replace the `update_serial_monitor` method (lines 174-180):

```ruby
  # シリアルモニター表示
  def update_serial_monitor(line)
    el = JS.global[:document].querySelector("#serial-monitor")
    begin
      current = el[:textContent].to_s
      el[:textContent] = (line + "\n" + current)[0, 2000]
    rescue JS::Error
    end
  end
```

- [ ] **Step 4: Remove unused glide_time alias**

Remove line 88:
```ruby
    when "glide_time"  then @glide_sec = value.to_f / 1000.0
```

This was for old UI compatibility. New UI only sends `"glide"`.

- [ ] **Step 5: Chrome integration test**

Open `http://localhost:8000/index.html?v=20260329g` in Chrome.
1. Init Audio → "Audio Ready", no console errors
2. JS `window.rubySerialOnReceive('<D:0450,AX:0100,AY:0050,AZ:1000>\n')` → Note/Freq/Dist display updates
3. No console errors

- [ ] **Step 6: Commit**

```
git add web/src/ruby/main.rb
git commit -m "refactor: replace JS compat wrappers with direct DOM updates in main.rb"
```

---

## Task 3: Add Preset UI Sync

**Files:**
- Modify: `web/src/ruby/main.rb`

- [ ] **Step 1: Add NODE_CONTROLS constant and sync_preset_ui method**

Add after `private` keyword in SynthApp:

```ruby
  NODE_CONTROLS = {
    fm_mod:     { waveform: "fm-mod-wave", freq: "fm-mod-freq", amp: "fm-mod-amp" },
    fm_carrier: { waveform: "fm-carrier-wave" },
    mixer:      { gain_value: "mixer-gain" },
    filter:     { filter_type: "filter-type", cutoff: "filter-cutoff", q: "filter-q" },
    master:     { gain_value: "master-gain" }
  }

  # プリセット切替時にUIコントロール値を同期
  def sync_preset_ui(patch)
    return unless patch
    NODE_CONTROLS.each do |node_name, attrs|
      node = patch[node_name]
      next unless node
      attrs.each do |attr, el_id|
        val = node.respond_to?(attr) ? node.send(attr) : nil
        next unless val
        set_value("##{el_id}", val)
      end
    end
  end

  # DOM要素のvalue属性を設定（select/range用）
  def set_value(selector, val)
    el = JS.global[:document].querySelector(selector)
    begin
      el[:value] = val.to_s
    rescue JS::Error
    end
  end
```

- [ ] **Step 2: Call sync_preset_ui in switch_preset**

Update `switch_preset` method:

```ruby
  def switch_preset(name)
    return unless @adapter
    @adapter.update_gain(0.0, @release)
    release_ms = (@release * 1000).to_i + 50
    JS.global.setTimeout(lambda {
      @presets.switch(name)
      sync_preset_ui(@presets.patch)
      @adapter.update_gain(@volume, @attack)
    }, release_ms)
  end
```

Add `sync_preset_ui(@presets.patch)` after `@presets.switch(name)`.

- [ ] **Step 3: Also sync on init_audio**

Add after `@presets.switch(:otamatone)` in `init_audio`:

```ruby
    sync_preset_ui(@presets.patch)
```

- [ ] **Step 4: Chrome integration test**

Open `http://localhost:8000/index.html` in Chrome.
1. Init Audio → Check FM Mod slider shows correct otamatone values (Freq=220, Amp=150)
2. Click "Acid" preset → FM Mod Amp slider moves to 300, Filter Cutoff to 600, Q to 8.0
3. Click "Clean" preset → FM Mod Amp slider moves to 0, Filter Cutoff to 4000
4. No console errors

- [ ] **Step 5: Commit**

```
git add web/src/ruby/main.rb
git commit -m "feat: add preset UI sync — node controls update on preset switch"
```

---

## Task 4: Rewrite web/CLAUDE.md

**Files:**
- Modify: `web/CLAUDE.md`

- [ ] **Step 1: Replace entire file**

```markdown
# picoruby-ot Web Synthesizer

Chrome-only web synth controlled by ATOM Matrix sensor data via Web Serial API.
Built with ruby.wasm (@ruby/4.0-wasm-wasi 2.8.1) + Web Audio API.

## Language Policy

- Documentation, git comments, code comments: English
- User communication: Japanese with suffix
- README.md: English only, no bold, no emoji

## Architecture

```
otmeiwa.rb (PicoRuby/ATOM Matrix)
    | USB Serial 115200bps
    | <D:NNNN,AX:NNNN,AY:NNNN,AZ:NNNN>\n
    v
index.html (Chrome)
    +-- JS: Web Serial async (connect/disconnect/readLoop)
    +-- ruby.wasm: Serial -> SensorMapper -> WebAdapter (Web Audio)
    +-- ruby.wasm: UIController (DOM, Canvas)
    +-- ruby.wasm: SynthPatch DSL -> PresetManager
```

### Control Principle

```
HTML  -> Static structure only
CSS   -> Styling only
JS    -> Web Serial async only (connect/disconnect/readLoop) + UI event bridge
Ruby  -> All control (Web Audio, DOM, Canvas, state, logic)
```

### Data Flow

```
Serial Port --JS async--> rubySerialOnReceive
                              |
                          Serial.receive
                              |
                          SynthApp.update(dist, ax, ay, az)
                              |
                    +---------+---------+
                    v         v         v
              SensorMapper  WebAdapter  UIController
              (compute)     (audio)     (display)
```

## File Structure

```
web/
+-- index.html              # Single-file app (HTML + CSS + minimal JS + ruby.wasm)
+-- test.html               # ruby.wasm unit test runner
+-- src/ruby/
    +-- main.rb             # SynthApp: callbacks, stateless update loop
    +-- serial.rb           # Frame parser + buffer + RX log
    +-- sensor_mapper.rb    # distance->note, accel->FM, curves, transpose
    +-- ui_controller.rb    # DOM updates, Canvas curves, oscilloscope, level meter
    +-- preset_manager.rb   # Preset definitions, switching
    +-- test_helper.rb      # Go-style mini test framework
    +-- *_test.rb           # Unit test files
    +-- synth_patch/
        +-- synth_patch.rb  # Patch DSL, compile to JSON
        +-- node.rb         # Base node, chaining (filter/gain/out)
        +-- fm_op_node.rb   # FM operator node
        +-- osc_node.rb     # Oscillator node
        +-- filter_node.rb  # BiquadFilter node
        +-- gain_node.rb    # Gain node
        +-- mixer_node.rb   # Mixer node
        +-- audio_adapter.rb # Abstract base
        +-- web_adapter.rb  # Web Audio direct control via JS.global
```

## ruby.wasm Integration

### JS -> Ruby (callbacks)

```ruby
JS.global[:rubySerialOnConnect]    = lambda { |baud| app.on_connect(baud) }
JS.global[:rubySerialOnDisconnect] = lambda { app.on_disconnect }
JS.global[:rubySerialOnReceive]    = lambda { |data| app.on_receive(data) }
JS.global[:rubyOnParamUpdate]      = lambda { |key, value| app.on_param(key.to_s, value) }
JS.global[:rubyInitAudio]          = lambda { app.init_audio }
```

### Ruby -> Web Audio (direct via JS.global)

```ruby
# Create AudioContext and nodes
@ctx = JS.global[:AudioContext].new
osc = @ctx.createOscillator
gain = @ctx.createGain
osc.connect(gain)
gain.connect(@ctx[:destination])
osc.start

# Smooth parameter updates
osc[:frequency].setTargetAtTime(440.0, @ctx[:currentTime].to_f, 0.005)
```

### Ruby -> DOM (direct via JS.global)

```ruby
doc = JS.global[:document]
el = doc.querySelector("#note-display")
el[:textContent] = "C4"
```

### JS::Object nil check (CRITICAL)

```ruby
# WRONG: obj.nil?  -> always false on JS::Object
# CORRECT:
obj.typeof == "undefined"

# For querySelector null results, use begin/rescue:
begin
  el[:textContent] = "text"
rescue JS::Error
  # querySelector returned null
end
```

### SynthPatch DSL

```ruby
patch = SynthPatch.build(adapter: adapter) do |syn|
  mod     = syn.fm_op(:triangle, freq: 220, amp: 150, name: :fm_mod)
  carrier = syn.fm_op(:triangle, freq: 220, name: :fm_carrier)
  carrier.fm(mod)
  syn.mix(carrier, name: :mixer)
     .filter(:lowpass, cutoff: 1200, q: 1.5, name: :filter)
     .gain(0.4, name: :master)
     .out
end
```

## Web Audio (Ruby Side)

### FM Synthesis

```ruby
# WebAdapter#create_web_audio_node builds nodes directly:
osc = @ctx.createOscillator
osc[:type] = "triangle"
osc[:frequency][:value] = 220.0
gain = @ctx.createGain
gain[:gain][:value] = 150.0
osc.connect(gain)
osc.start
# FM: modulator gain -> carrier frequency
gain.connect(carrier_osc[:frequency])
```

### Stateless Update (every frame, no branching)

```ruby
def update(dist_mm, ax, ay, az)
  freq     = @mapper.note_to_freq(@mapper.distance_to_note(dist_mm))
  fm_depth = @mapper.accel_to_fm_depth(ax, ay, az)
  in_range = @mapper.in_range?(dist_mm)
  @adapter.update_freq(freq, @glide_sec)
  @adapter.update_fm_depth(fm_depth)
  @adapter.update_gain(in_range ? @volume : 0.0, in_range ? @attack : @release)
end
```

No @sounding flag. Default gain=0. setTargetAtTime handles all transitions.

## Web Serial API (JS Only)

Web Serial requires async/await. Kept in JS as glue:

```javascript
serialPort = await navigator.serial.requestPort();
await serialPort.open({ baudRate: 115200 });
// Read loop calls rubySerialOnReceive(value)
```

Requirements: Chrome only, HTTPS or localhost, user gesture required.

## Canvas Visualization (Ruby Side)

Four canvases drawn by UIController via JS.global:
- `#oscilloscope`: Waveform (AnalyserNode getByteTimeDomainData)
- `#level-meter`: RMS level bar
- `#dist-curve-canvas`: Distance->pitch mapping curve (Lin/Log/Exp/S)
- `#accel-curve-canvas`: Accel->FM depth mapping curve

## Testing

### Unit Tests (ruby.wasm, Go test style)

```
web/test.html    -> loads ruby.wasm + production code + *_test.rb files
test_helper.rb   -> assert_equal, assert, assert_in_delta, group, test_summary
```

127 tests covering: SensorMapper, Serial, SynthPatch DSL, UIController.
Results: console.log + DOM #test-result element.

### Cache Busting

ruby.wasm aggressively caches. All script src use `?v=YYYYMMDD` suffix.
Update suffix when changing Ruby files.

## JS Minimalism Policy

**JS is Web Serial async glue only.** All logic in Ruby.

- JS handles: Web Serial connect/disconnect/readLoop, UI event -> rubyOnParamUpdate bridge
- Ruby handles: Web Audio, DOM updates, Canvas drawing, frame parsing, sensor mapping, state
- Do NOT implement business logic in JS

## Development Workflow

1. Edit Ruby files in `web/src/ruby/`
2. Edit `web/index.html` for HTML/CSS changes (JS should rarely change)
3. Serve: `rake server:start` or `cd web && ruby -run -ehttpd . -p8000`
4. Test: `http://localhost:8000/test.html` (unit tests)
5. Verify: `http://localhost:8000/index.html` (integration)
6. Cache: Bump `?v=` suffix in index.html and test.html when changing Ruby files

## Commit Policy

- Commits via subagent `commit` (never direct git)
- No push (human manually pushes)
```

- [ ] **Step 2: Commit**

```
git add web/CLAUDE.md
git commit -m "docs: rewrite web/CLAUDE.md to reflect new Ruby-centric architecture"
```

---

## Task 5: Final Integration Verification

- [ ] **Step 1: Run unit tests**

Open `http://localhost:8000/test.html` in Chrome.
Expected: 127 tests, ALL PASS.

- [ ] **Step 2: Full integration test**

Open `http://localhost:8000/index.html` in Chrome.
1. Init Audio → "Audio Ready", no console errors
2. `window.rubySerialOnReceive('<D:0450,AX:0100,AY:0050,AZ:1000>\n')` → Note: C4, 261Hz, 450mm
3. Switch to "Acid" preset → Filter Cutoff slider shows 600, Q shows 8.0, FM Mod Amp shows 300
4. Click "Log" curve button → Dist→Pitch canvas redraws with log curve
5. Click Octave ▶ → dot indicator moves right, note goes up one octave
6. Click "Send Frame" in Test Mode → display updates
7. Open Serial Monitor → collapsible section works
8. No console errors at any point

- [ ] **Step 3: Commit any fixes**

```
git add -u
git commit -m "fix: address integration test findings"
```
