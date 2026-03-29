# Web Synth Cleanup — JS Dead Code Removal, Ruby Unification, Preset UI Sync

## Overview

Remove dead JS code, unify all control paths through Ruby, add preset UI synchronization, and rewrite web/CLAUDE.md to reflect the new architecture.

**Target:** Chrome for macOS 146.0.7680.165+

## Grand Design

### Control Principle

```
HTML  → Static structure only
CSS   → Styling only
JS    → Web Serial async only (connect/disconnect/readLoop)
Ruby  → All control (Web Audio, DOM, state, logic)
```

### Data Flow (unidirectional, no branching)

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

### JS Responsibilities (exhaustive list)

1. Web Serial connection/disconnection/read loop (async API)
2. ruby.wasm loader
3. UI event listeners -> `rubyOnParamUpdate` bridge
4. `appendSerialMonitor` helper (DOM text append)

JS does NOT touch: Web Audio nodes, DOM text updates, Canvas drawing, state management.

### Ruby File Responsibilities (one file, one job)

| File | Responsibility | Dependencies |
|------|---------------|-------------|
| `main.rb` | App loop, callback registration | Serial, SensorMapper, PresetManager, UIController, WebAdapter |
| `sensor_mapper.rb` | distance->note, accel->FM depth, curves, transpose | None (pure Ruby) |
| `serial.rb` | Frame parsing, buffer management | None (pure Ruby) |
| `ui_controller.rb` | DOM updates, Canvas drawing, animation | JS.global (DOM/Canvas only) |
| `preset_manager.rb` | Preset definitions, switching | SynthPatch DSL |
| `web_adapter.rb` | Web Audio node creation and manipulation | JS.global (AudioContext only) |
| `synth_patch/*.rb` | Patch DSL, node definitions | None (pure Ruby) |

## Deletions

### index.html JS — Remove

| Function | Lines | Reason |
|----------|-------|--------|
| `synthPatchBuild` | ~63 | Dead code. Ruby WebAdapter builds directly |
| `synthPatchUpdateParam` | ~9 | Dead code. Ruby adapter.update_param operates directly |
| `updateSensorParams` | ~30 | Ruby update() operates Web Audio directly. Dual-update source |
| `sp` object, `_prevActive`, `PRESET_WAVES` | ~10 | State for synthPatchBuild. Unused |
| `window.synthMasterGain`, `fmDepthScale`, `synthGlideTime`, `synthFmDepthManual`, `synthModRatio` | ~5 | Ruby manages these |
| `ensureAnalyser` function | ~10 | Ruby WebAdapter creates analyser directly |

### index.html JS — Keep

| Function | Reason |
|----------|--------|
| Web Serial (connect/disconnect/readLoop) | Async API, impractical from Ruby |
| Init Audio button handler | Calls `rubyInitAudio()` only |
| UI event listener group | `rubyOnParamUpdate` bridge |
| `appendSerialMonitor` | DOM text append helper |
| `updateSerialStatus` | Migrate to Ruby direct DOM update (see Additions) |

### main.rb — Remove

| Code | Reason |
|------|--------|
| `update_serial_status` JS compat wrapper | Replace with direct DOM update |
| `update_serial_monitor` JS compat wrapper | Replace with direct DOM update |
| `update_sensor_display` call to `JS.global.updateSensorDisplay` | Already using `set_text` directly |

## Additions

### Preset UI Sync

On preset switch, sync all node control values to DOM:

```
Preset switch
  |
  +- WebAdapter.build_graph(json)  -> rebuild Web Audio nodes
  |
  +- sync_preset_ui(patch)         -> update DOM controls
       |
       +- FM Mod:    wave, freq, amp
       +- FM Carrier: wave
       +- Mixer:     gain
       +- Filter:    type, cutoff, q
       +- Master:    gain
```

Implementation:

```ruby
NODE_CONTROLS = {
  fm_mod:     { wave: "fm-mod-wave", freq: "fm-mod-freq", amp: "fm-mod-amp" },
  fm_carrier: { wave: "fm-carrier-wave" },
  mixer:      { gain: "mixer-gain" },
  filter:     { type: "filter-type", cutoff: "filter-cutoff", q: "filter-q" },
  master:     { gain: "master-gain" }
}
```

Read values from `patch[:node_name].waveform`, `.freq`, `.amp`, `.cutoff`, `.q`, `.gain_value`, `.filter_type` via existing attr_readers. Write to DOM with `el[:value] = val`.

### Direct DOM Updates for Serial Status

Replace JS compat wrappers with `set_text`/`set_style` calls:

```ruby
def update_serial_status_display(connected)
  el = JS.global[:document].querySelector("#serial-status")
  begin
    el[:style][:color] = connected ? "#4caf50" : "#f44336"
  rescue JS::Error
  end
end
```

### Serial Monitor Direct Update

```ruby
def update_serial_monitor_display(line)
  el = JS.global[:document].querySelector("#serial-monitor")
  begin
    current = el[:textContent].to_s
    el[:textContent] = (line + "\n" + current)[0, 2000]
  rescue JS::Error
  end
end
```

## web/CLAUDE.md Rewrite

Full rewrite to reflect new architecture:

- Architecture diagram: Ruby controls everything, JS is Web Serial async only
- File structure: current file list (serial.rb, sensor_mapper.rb, ui_controller.rb, etc.)
- Ruby->JS: `JS.global[:AudioContext].new`, `JS.global[:document].querySelector`
- JS->Ruby: `rubySerialOnReceive`, `rubyOnParamUpdate`, `rubyInitAudio`
- Web Audio: Ruby-side `@ctx.createOscillator` etc.
- Canvas: `#oscilloscope`, `#level-meter`, `#dist-curve-canvas`, `#accel-curve-canvas`
- Testing: `test.html` + `test_helper.rb` (Go test style), 127 tests

## Testing Strategy

### Unit Tests (existing, must stay green)

127 tests in test.html — SensorMapper, Serial, SynthPatch DSL, UIController.
No changes to test files needed (deletions are JS-side and main.rb wrappers only).

### Chrome Integration Verification

After each deletion step:
1. Open index.html, Init Audio
2. Send test frame -> Note/Freq/Dist display updates
3. Switch preset -> audio changes, UI controls sync
4. Switch curve -> canvas redraws
5. Octave up/down -> dot indicator updates
6. No console errors
