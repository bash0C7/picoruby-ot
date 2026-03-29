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
JS    -> Web Serial async only + UI event bridge
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

### Ruby -> Web Audio (direct via JS.global)

```ruby
@ctx = JS.global[:AudioContext].new
osc = @ctx.createOscillator
osc[:frequency].setTargetAtTime(440.0, @ctx[:currentTime].to_f, 0.005)
```

### Ruby -> DOM (direct via JS.global)

```ruby
el = JS.global[:document].querySelector("#note-display")
begin
  el[:textContent] = "C4"
rescue JS::Error
end
```

### JS::Object nil check (CRITICAL)

```ruby
# WRONG: obj.nil?  -> always false on JS::Object
# For querySelector null results, use begin/rescue:
begin
  el[:textContent] = "text"
rescue JS::Error
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

## Stateless Update (every frame)

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

No @sounding flag. Default gain=0. setTargetAtTime handles transitions.

## Web Serial API (JS Only)

Async API kept in JS as glue. Calls `rubySerialOnReceive(value)`.
Requirements: Chrome only, HTTPS or localhost, user gesture required.

## Canvas (Ruby Side via UIController)

- `#oscilloscope`: Waveform (AnalyserNode)
- `#level-meter`: RMS level bar
- `#dist-curve-canvas`: Distance->pitch curve (Lin/Log/Exp/S)
- `#accel-curve-canvas`: Accel->FM depth curve

## Testing

Unit tests: `test.html` + `test_helper.rb` (Go test style). 127 tests.
Cache: ruby.wasm caches aggressively. Bump `?v=` suffix when changing Ruby files.

## JS Minimalism Policy

JS is Web Serial async glue + UI event bridge only. All logic in Ruby.

## Development Workflow

1. Edit Ruby files in `web/src/ruby/`
2. Test: `http://localhost:8000/test.html`
3. Verify: `http://localhost:8000/index.html`
4. Cache: Bump `?v=` suffix when changing Ruby files

## Commit Policy

- Commits via subagent `commit` (never direct git)
- No push (human manually pushes)
