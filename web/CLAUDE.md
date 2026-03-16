# picoruby-ot Web Synthesizer

Chrome-only web synth controlled by ATOM Matrix sensor data via Web Serial API.
Built with ruby.wasm (@ruby/4.0-wasm-wasi 2.8.1) + Web Audio API.

## Language Policy

- Documentation, git comments, code comments: English
- User communication: Japanese with 「ピョン。」suffix
- README.md: English only, no bold, no emoji

## Architecture

```
otmeiwa.rb (PicoRuby/ATOM Matrix)
    │ USB Serial 115200bps
    │ <D:NNNN,AX:NNNN,AY:NNNN,AZ:NNNN>\n
    ▼
index.html (Chrome)
    ├── Web Serial API → JS → rubySerialOnReceive()
    ├── ruby.wasm: SerialManager → SerialProtocol → SensorMapper
    ├── ruby.wasm: SynthPatch DSL → WebAdapter → JS.global.synthPatchBuild(json)
    └── Web Audio API (FM OscillatorNode + BiquadFilter + GainNode + AnalyserNode)
```

## File Structure

```
web/
├── index.html              # Single-file app (HTML + CSS + JS + embedded Ruby)
└── src/ruby/
    ├── main.rb             # SynthApp: serial callbacks, param updates
    ├── serial_protocol.rb  # Frame parser <D:,AX:,AY:,AZ:>
    ├── serial_manager.rb   # Connection state, RX buffer, RX log
    ├── sensor_mapper.rb    # distance→freq (log scale), accel→FM depth
    ├── js_bridge.rb        # Ruby↔JS: updateSensorParams, updateSensorDisplay
    └── synth_patch/        # FM synth DSL (from ruby_sound_visualizer)
        ├── synth_patch.rb, node.rb, osc_node.rb, fm_op_node.rb
        ├── filter_node.rb, gain_node.rb, mixer_node.rb
        ├── audio_adapter.rb, web_adapter.rb
```

## ruby.wasm Integration

### JS → Ruby (callbacks)

Register Ruby lambdas on `JS.global` from Ruby code:

```ruby
JS.global[:rubySerialOnReceive] = lambda do |data|
  app.on_serial_receive(data)
end
```

Then call from JS: `rubySerialOnReceive(data)`

### Ruby → JS (calling JS functions)

```ruby
# Call JS function
JS.global.updateSensorParams(freq, fm_depth, active ? 1 : 0)
JS.global.synthPatchBuild(json_string)

# Set JS global variable
JS.global[:synthMasterGain] = 0.4

# JS::Object nil check (CRITICAL)
# WRONG: obj.nil?  → always returns false on JS::Object
# CORRECT:
obj.typeof == "undefined"
```

### SynthPatch DSL

```ruby
patch = SynthPatch.build(adapter: SynthPatch::WebAdapter.new) do |syn|
  mod     = syn.fm_op(:sine, freq: 220, amp: 50, name: :fm_mod)
  carrier = syn.fm_op(:sine, freq: 220, name: :fm_carrier)
  carrier.fm(mod)
  syn.mix(carrier, name: :mixer)
     .filter(:lowpass, cutoff: 800, q: 1.2, name: :filter)
     .gain(0.4, name: :master)
     .out
end

# Update node parameter
patch[:filter]&.set_param(:cutoff, 1200)
```

`WebAdapter#build(json)` calls `JS.global.synthPatchBuild(json)`.

## Web Audio API (JS Side)

### FM Synthesis Pattern

```javascript
// Carrier OscillatorNode
carrier = ctx.createOscillator();
carrier.type = 'sine';
carrier.frequency.value = 440;

// Modulator → carrier.frequency (FM)
modulator = ctx.createOscillator();
modDepth = ctx.createGain();          // FM depth control
modulator.connect(modDepth);
modDepth.connect(carrier.frequency);  // Key: connect to frequency AudioParam
```

### Smooth Theremin-style Updates

```javascript
// Use setTargetAtTime for smooth glide (no zipper noise)
const T = 0.05;  // 50ms time constant
carrier.frequency.setTargetAtTime(freq, ctx.currentTime, T);
modDepth.gain.setTargetAtTime(fmAmp, ctx.currentTime, T);
```

### AnalyserNode (Oscilloscope / Level Meter)

```javascript
analyser = ctx.createAnalyser();
analyser.fftSize = 2048;
masterGain.connect(analyser);
analyser.connect(ctx.destination);

// Oscilloscope: time domain
const buf = new Float32Array(analyser.fftSize);
analyser.getFloatTimeDomainData(buf);

// Level: RMS calculation
let rms = Math.sqrt(buf.reduce((s, v) => s + v*v, 0) / buf.length);
let dBFS = 20 * Math.log10(rms + 1e-9);
```

## Web Serial API (Chrome Only)

```javascript
port = await navigator.serial.requestPort();
await port.open({ baudRate: 115200 });

const reader = port.readable
  .pipeThrough(new TextDecoderStream())
  .getReader();

(async () => {
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    rubySerialOnReceive(value);  // → Ruby
  }
})();
```

Requirements: Chrome only, HTTPS or localhost, user gesture required.

## Visualization (Canvas 2D)

Four canvas elements in index.html:
- `gcanvas`: Synth patch graph (clickable nodes, node editor)
- `hcanvas`: Sensor history (distance sparkline + AX/AY/AZ bars)
- `ocanvas`: Oscilloscope (zero-crossing stabilized)
- `lcanvas`: Level meter (RMS dBFS, peak hold, color gradient)

Canvas scaling for HiDPI:
```javascript
const rect = canvas.getBoundingClientRect();
const sx = canvas.width / rect.width;   // click X scale
const sy = canvas.height / rect.height; // click Y scale
```

## JS Minimalism Policy

**Keep JS to Web API glue only.** All logic in Ruby (ruby.wasm).

- JS handles: Web Serial connect/disconnect, Web Audio node wiring, Canvas draw loop
- Ruby handles: Frame parsing, sensor mapping, synth parameter calculation, state management
- Do NOT implement business logic in JS

## Development Workflow

1. Edit Ruby files in `web/src/ruby/`
2. Edit `web/index.html` for JS/HTML/CSS changes
3. Serve: `cd web && ruby -run -ehttpd . -p8000`
4. Open: `http://localhost:8000/index.html` in Chrome
5. Verify: Check Chrome DevTools console for errors

Cache note: ruby.wasm aggressively caches. Append `?v=N` to URL when testing changes.

## Commit Policy

- Commits via subagent `commit` (never direct git)
- No push (human manually pushes)
