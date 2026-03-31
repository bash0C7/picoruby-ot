# picoruby-ot Web Synthesizer

Chrome-only portamento drone synth controlled by ATOM Matrix sensor data via Web Serial API.
Built with ruby.wasm (@ruby/4.0-wasm-wasi 2.8.1) + Web Audio API.

## Language Policy

- Documentation, git comments, code comments: English
- User communication: Japanese with suffix
- README.md: English only, no bold, no emoji

## Instrument Concept: Portamento Drone

The instrument is a **continuously sounding drone with portamento**.

- Sound is always on while serial is connected (drone mode)
- Distance controls pitch continuously — no note quantization, no scale snap
- Pitch slides smoothly between frames (violin-like portamento)
- Accel (shake) controls FM depth (timbre change)
- Gain changes only on connect (fade in) and disconnect (fade out)

This is NOT a trigger-based instrument. There is no note-on/note-off.

## Architecture

```
otmeiwa.rb (PicoRuby/ATOM Matrix)
    | USB Serial 115200bps ~20fps
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
JS    -> Web Serial async + UI event bridge + _audioParamBatchUpdate helper
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
                    v                   v
              SensorMapper         WebAdapter._audioParamBatchUpdate (JS)
              distance_to_midi_float    cancelAndHoldAtTime + setTargetAtTime
              note_to_freq              (carrier freq, mod freq, FM depth)
              accel_to_fm_depth
```

## Portamento Implementation

### Core: setTargetAtTime with TC ≈ frame period

Serial frame rate is ~40fps (~25ms interval) — VL53L0X hardware measurement cycle drives the loop, no artificial sleep. Glide time constant (TC) must be close to the frame period for smooth inter-frame interpolation:

| TC | Effect |
|----|--------|
| 5ms | TC << frame period → snaps to each frame's value → choppy steps |
| **20ms** | TC ≈ frame period → exponential curve from each frame overlaps the next → smooth portamento |
| 60ms+ | TC >> frame period → significant lag behind hand position |

**Default glide: 20ms.** TC/frame ratio ≈ 0.8 — this ratio is the portamento invariant.

### cancelAndHoldAtTime (CRITICAL — never use cancelScheduledValues)

```js
// CORRECT: holds current interpolated value, starts new curve from there
param.cancelAndHoldAtTime(now);
param.setTargetAtTime(newFreq, now, tc);

// WRONG: snaps back to initial value (220Hz), destroys portamento
param.cancelScheduledValues(0);
```

### JS Batch Helper (minimize ruby.wasm JS::Object allocations)

Every ruby.wasm JS interop call creates a JS::Object in the WASM heap. To reduce
per-frame allocations to one call, freq + FM depth + master gain updates are delegated to a JS helper:

```js
window._audioParamBatchUpdate = function(carrierFreq, modFreq, fmDepthScaled, glide, targetGain, gainTc) {
  var now = ctx.currentTime;
  var tc = glide > 0.001 ? glide : 0.001;
  _carrierFreqParam.cancelAndHoldAtTime(now);
  _carrierFreqParam.setTargetAtTime(carrierFreq, now, tc);
  _modFreqParam.cancelAndHoldAtTime(now);
  _modFreqParam.setTargetAtTime(modFreq, now, tc);  // independent: modFreq = carrierFreq * cm_ratio
  _modGainParam.cancelAndHoldAtTime(now);
  _modGainParam.setTargetAtTime(fmDepthScaled, now, 0.01);
  _masterGainParam.cancelAndHoldAtTime(now);
  _masterGainParam.setTargetAtTime(targetGain, now, gainTc);
};
```

Ruby side calls once per frame:
```ruby
mod_freq = freq * @cm_ratio
@adapter.batch_update(freq, mod_freq, fm_depth, @glide_sec, gain, @release)
```

AudioParam references (`_carrierFreqParam`, `_modFreqParam`, `_modGainParam`, `_masterGainParam`, `_fbGainParam`)
are cached in `cache_audio_params` after `build_graph` and re-exposed to JS globals on preset switch.

## Stateless Update Loop

```ruby
def update(dist_mm, ax, ay, az)
  return unless @adapter
  midi_float = @mapper.distance_to_midi_float(dist_mm)
  freq       = @mapper.note_to_freq(midi_float)
  fm_depth   = @mapper.accel_to_fm_depth(ax, ay, az)
  @mute_dist = @mute_dist ? @mute_dist * 0.7 + dist_mm * 0.3 : dist_mm.to_f
  gain       = @mute_dist < 25 ? 0.0 : @volume
  mod_freq = freq * @cm_ratio
  @adapter.batch_update(freq, mod_freq, fm_depth, @glide_sec, gain, @release)
  note_str = @mapper.note_name(midi_float.round)
  update_sensor_display(dist_mm, ax, ay, az, freq, fm_depth, note_str)
end
```

No `@sounding` flag. No `in_range?` check. Gain controlled every frame via batch_update.

## Near-zero Mute with Chattering Suppression

Drone mutes when distance < 25mm (dead zone / stop gesture).

Raw distance is NOT used directly for the mute threshold — sensor chattering causes
spurious sub-25mm readings, especially during vigorous playing. Instead, an exponential
moving average `@mute_dist` low-pass filters the distance signal:

```ruby
@mute_dist = @mute_dist * 0.7 + dist_mm * 0.3   # α=0.3, history weight=0.7
gain = @mute_dist < 25 ? 0.0 : @volume
```

Why exponential smoothing beats a consecutive-frame counter:
- Micro-movements (always present) produce symmetric noise → average stays at true position
- Chattering spikes are asymmetric outliers → each spike only moves @mute_dist by 30%
- Genuine slow approach to 25mm: @mute_dist tracks the hand over ~5 frames (~250ms)
- Vigorous playing: even 3 consecutive low readings won't push @mute_dist below 25mm
  if the true average position is far above the threshold

Do NOT replace `@mute_dist` with raw `dist_mm` for gain decisions.

## Sensor Mapping

```
Distance 30-570mm  -> MIDI 48-72 (2 octaves, C3-C5, linear)
                   -> freq via equal temperament: 440 * 2^((midi-69)/12)
                   -> Note display: A3=440Hz convention (midi/12 - 2)

Accel (ax+ay+az)   -> FM depth 0.0-1.0 via apply_curve(ratio, curve_type)
                   -> Curves: linear / log / exp / s_curve
```

**Operational range (real hardware, VL53L0X):** 30mm minimum, 570mm maximum.

Distance mapping is linear to MIDI note (equal semitone spacing per mm: ~23mm/semitone).
No scale quantization. No note snapping.

## File Structure

```
web/
+-- index.html              # Single-file app (HTML + CSS + minimal JS + ruby.wasm)
+-- test.html               # ruby.wasm unit test runner
+-- src/ruby/
    +-- main.rb             # SynthApp: callbacks, portamento update loop
    +-- serial.rb           # Frame parser + buffer + RX log
    +-- sensor_mapper.rb    # distance->MIDI float, accel->FM depth, curves, transpose
    +-- ui_controller.rb    # DOM updates, Canvas curves, oscilloscope, level meter
    +-- preset_manager.rb   # Preset definitions (otamatone/clean/acid/retro), switching
    +-- test_helper.rb      # Go-style mini test framework
    +-- *_test.rb           # Unit test files
    +-- synth_patch/
        +-- synth_patch.rb, node.rb, fm_op_node.rb, osc_node.rb
        +-- filter_node.rb, gain_node.rb, mixer_node.rb
        +-- audio_adapter.rb, web_adapter.rb
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

### Ruby -> DOM (direct via JS.global)

```ruby
el = JS.global[:document].querySelector("#note-display")
begin
  el[:textContent] = "C4"
rescue JS::Error
  # querySelector returned null — always rescue, never use obj.nil? (always false on JS::Object)
end
```

### DOM element caching (CRITICAL for 20fps loop)

Cache DOM element references in `init_audio`, reuse every frame:
```ruby
@el_note = JS.global[:document].querySelector("#note-display")
# reuse @el_note in update loop — avoids JS::Object allocation per frame
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

## UI Controls

| Control | Default | Range |
|---------|---------|-------|
| Glide | 40ms | 0-200ms |
| Attack | 10ms | 1-2000ms |
| Release | 300ms | 10-5000ms |
| Preset | otamatone | otamatone / clean / acid / retro |
| Octave | center | ±2 octave (dot indicator) |
| Filter type | radio buttons | Low Pass / High Pass / Band Pass / Notch |
| Accel curve | linear | linear / log / exp / s_curve |

## Canvas (Ruby Side via UIController)

- `#oscilloscope`: Waveform (AnalyserNode)
- `#level-meter`: RMS level bar
- `#accel-curve-canvas`: Accel->FM depth curve (redraws on curve type change)

## Memory Monitor (JS, header)

Displays `Mem:used/totalMB ETA~Nm` every 10s using `performance.memory`.
ETA estimates time to 2GB WASM heap crash based on growth rate.
Useful for detecting ruby.wasm memory leaks during development.

## Testing

Unit tests: `test.html` + `test_helper.rb` (Go test style). 127 tests.
Cache: ruby.wasm caches aggressively. Bump `?v=` suffix when changing Ruby files.

## JS Minimalism Policy

JS responsibilities (exhaustive):
1. Web Serial connect/disconnect/readLoop (async API)
2. ruby.wasm loader
3. UI event listeners → `rubyOnParamUpdate` bridge
4. `_audioParamBatchUpdate` helper (AudioParam updates, 1 call/frame)
5. `_audioReleaseVoice` helper (release voice trigger)
6. `_createReverbIR(decay)` helper (ConvolverNode impulse response buffer generation)
7. `_createDistortionCurve(drive)` helper (WaveShaperNode curve generation — gabber-aggressive d²/25 scaling)
8. Memory monitor

JS does NOT: touch Web Audio nodes directly, manage state, update DOM text.

## Development Workflow

1. Edit Ruby files in `web/src/ruby/`
2. Bump `?v=` cache suffix for changed files in `index.html`
3. Test: `http://localhost:8000/test.html`
4. Verify: `http://localhost:8000/index.html`

## Commit Policy

- Commits via subagent `commit` (never direct git)
- No push (human manually pushes)
