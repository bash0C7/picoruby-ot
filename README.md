# picoruby-ot: ATOM Matrix Instrument Project

A PicoRuby (R2P2-ESP32) application for **M5 ATOM Matrix (ESP32-PICO-D4)** featuring three interactive musical instruments: automatic MIDI drum machine, PWM distance synthesizer, and a web-based polyphonic FM synthesizer controlled via serial sensor data.

## Overview

**picoruby-ot** provides three complementary instruments running on ATOM Matrix, plus a companion web synth app:

### otma.rb - Auto Drum Machine
- **Automatic rhythm playback** via MIDI sound synthesis
- **16-step drum patterns** with kick, snare, hi-hats, toms, claps
- **Real-time MIDI output** (31250 bps) to external sound module
- **Synchronized LED visualization** reflecting drum group history
- **Button control** for crash cymbal triggering

### otpwm.rb - Distance Sensor PWM Instrument
- **Distance-to-frequency mapping** (20mm-300mm → 200Hz-1000Hz)
- **PWM speaker direct drive** via GPIO33
- **VL53L0X ToF sensor** for responsive pitch control
- **WS2812 LED strip** (29 LEDs) with dynamic color response to sound
- **Ambient wave visualization** with smooth LED patterns
- **Button**: mute/unmute

### otmeiwa.rb - Sensor Serial Output Instrument
- **Serial frame output** to Chrome web synth via UART0/USB
- **Distance range extended**: 20mm-900mm
- **Accel calibration**: button press saves baseline for relative hand motion
- **Frame format**: `<D:NNNN,AX:NNNN,AY:NNNN,AZ:NNNN>` at ~20fps
- **WS2812 LED strip** (15 LEDs): distance→hue, accel→saturation
- **Button**: toggle active + calibrate accelerometer baseline

### web/ - Polyphonic FM Synthesizer (Chrome)
- **ruby.wasm** application controlled by `otmeiwa.rb` serial data
- **FM synthesis**: carrier + modulator pair; distance→pitch, accel→FM depth
- **Visual synth patch graph**: clickable node editor (waveform, FM depth, filter, gain)
- **Oscilloscope**: zero-crossing stabilized time-domain waveform
- **Level meter**: RMS dBFS with peak hold and color gradient
- **Sensor history**: distance sparkline + AX/AY/AZ level bars
- **Web Serial API** at 115200 bps

## Hardware

**Device**: M5 ATOM Matrix (ESP32-PICO-D4)

**Configuration**:
```
┌─────────────────────┐
│  ATOM Matrix        │
├─────────────────────┤
│ GPIO39 (built-in)   │ ──→ Button (all apps)
│ GPIO21/25 (J3)      │ ──→ I2C bus (otpwm / otmeiwa)
│ GPIO22/19 (PortD)   │ ──→ MIDI UART (otma)
│ GPIO33 (J4)         │ ──→ PWM Speaker (otpwm)
│ GPIO26 (Grove)      │ ──→ WS2812 LED control (otpwm / otmeiwa)
│ GPIO22 (PortD)      │ ──→ WS2812 LED control (otma)
│ UART0 (USB)         │ ──→ Serial frame output (otmeiwa → Chrome)
└─────────────────────┘
```

**External Sensors** (otpwm.rb / otmeiwa.rb):
- VL53L0X (Unit ToF) - Distance measurement via J3 (I2C)
- MPU6886 (internal) - Accelerometer/gyro

**External Components** (otma.rb):
- MIDI Unit (SAM2695 or compatible) - Sound module

## File Structure

```
picoruby-ot/
├── src_components/R2P2-ESP32/
│   ├── storage/home/
│   │   ├── otma.rb              # Auto drum machine (MIDI)
│   │   ├── otpwm.rb             # Distance sensor PWM instrument
│   │   └── otmeiwa.rb           # Sensor serial output instrument
│   └── components/picoruby-esp32/
│       └── picoruby/build_config/
│           └── xtensa-esp.rb     # Xtensa (ESP32) build config
├── web/
│   ├── index.html               # Single-file web synth app (JS + HTML + CSS)
│   ├── CLAUDE.md                # Web development guidelines (ruby_sound_visualizer)
│   └── src/ruby/
│       ├── main.rb              # App init, serial callbacks, synth control
│       ├── serial_protocol.rb   # Sensor frame parser <D:,AX:,AY:,AZ:>
│       ├── serial_manager.rb    # Web Serial connection state
│       ├── sensor_mapper.rb     # Sensor values → synth parameters
│       ├── js_bridge.rb         # Ruby↔JS interop
│       └── synth_patch/         # DSL-based FM synth (from ruby_sound_visualizer)
│           ├── synth_patch.rb
│           ├── node.rb
│           ├── osc_node.rb
│           ├── fm_op_node.rb
│           ├── filter_node.rb
│           ├── gain_node.rb
│           ├── mixer_node.rb
│           ├── audio_adapter.rb
│           └── web_adapter.rb
├── Rakefile                      # Build automation
├── CLAUDE.md                     # Project development guidelines
├── README.md                     # This file
└── .ruby-version                 # 4.0.1 (for web development)
```

## Quick Start

**Prerequisites**:
- ESP-IDF installed at `$HOME/esp/esp-idf/`
- Homebrew with OpenSSL (macOS)
- M5 ATOM Matrix device
- Chrome (for web synth)

**Setup**:
```bash
# Step 1: Initialize project and build environment
rake init

# Step 2: Build and flash
rake build APP=otma && rake flash    # Auto drum machine
rake build APP=otpwm && rake flash   # PWM distance instrument
rake build APP=otmeiwa && rake flash # Serial output instrument

# Step 3: Monitor serial output
rake monitor
```

**Web synth** (Chrome only, requires Web Serial API):
```bash
# Serve web/ directory
cd web && ruby -run -ehttpd . -p8000
# Open http://localhost:8000/index.html
```

## Usage

### otma.rb (Auto Drum Machine)

1. Flash `otma.rb` to ATOM Matrix
2. Connect MIDI Unit to PortD/J5 (GPIO22=TX, GPIO19=RX)
3. Connect MIDI cable from Unit to sound module
4. Power on - automatic drum pattern playback begins
5. Press button to trigger crash cymbal + fill-in pattern

**MIDI Configuration**:
- Baud: 31250 (standard MIDI)
- Channel: 10 (drums)
- Notes: KICK=36, SNARE=38, HI_HAT=42/46, TOMS=41/47/50, CLAP=39, CRASH=49

### otpwm.rb (Distance Sensor PWM Instrument)

1. Flash `otpwm.rb` to ATOM Matrix
2. Connect sensors via J3 (I2C: GPIO25=SDA, GPIO21=SCL)
3. Connect PWM speaker to J4 (GPIO33)
4. Connect WS2812 LED strip to GPIO26
5. Power on - move hand near sensor to change pitch
6. Press button to mute/unmute

**Sensor Ranges**:
- Distance: 20mm (low) to 300mm (high) → 200Hz to 1000Hz
- LED: 29 pixels, 4 hue bands by distance

### otmeiwa.rb + web/ (Sensor → Chrome FM Synth)

1. Flash `otmeiwa.rb` to ATOM Matrix
2. Connect sensors via J3 (I2C: GPIO25=SDA, GPIO21=SCL)
3. Connect WS2812 LED strip to GPIO26
4. Connect ATOM Matrix to Mac via USB
5. Open `web/index.html` in Chrome
6. Click **Init Audio**, then **Connect** (select ATOM Matrix serial port)
7. Press button on ATOM Matrix to enable + calibrate accelerometer
8. Move hand: distance changes pitch, acceleration changes FM timbre

**Serial Protocol**:
```
<D:NNNN,AX:NNNN,AY:NNNN,AZ:NNNN>\n
```
- `D`: distance mm (20-900)
- `AX/AY/AZ`: accel relative to calibration baseline

## LED Visualization

### otma.rb
- Group 1 (KICK): Red (hue 0)
- Group 2 (SNARE): Cyan (hue 128)
- Group 3 (CLAP): Magenta (hue 192)
- Group 4 (TOM): Yellow (hue 64)

### otpwm.rb
- 4 distance bands → 4 hue zones
- Brightness follows duty cycle (volume)
- Wave offset animation tied to distance

### otmeiwa.rb
- Hue: distance 20-900mm → 0-383 (full spectrum)
- Saturation: accel Manhattan magnitude → 100-255
- Active: brightness 150; muted: dim grey (sat=0, bri=20)

## Web Synth Architecture

```
otmeiwa.rb (PicoRuby on ATOM Matrix)
    │ USB Serial  <D:250,AX:12,AY:-8,AZ:3>\n
    ▼
web/index.html (Chrome)
    ├── Web Serial API → SerialManager.rb → SerialProtocol.rb
    ├── SensorMapper.rb: distance→log-freq, accel→FM depth
    ├── SynthPatch.rb (DSL): fm_mod→fm_carrier→mixer→filter→master
    ├── WebAdapter.rb → JS synthPatchBuild / updateSensorParams
    └── Web Audio API
        ├── FM Oscillator pair (carrier + modulator)
        ├── BiquadFilter (lowpass, adjustable)
        ├── GainNode (master)
        ├── AnalyserNode → Oscilloscope + Level Meter
        └── AudioContext.destination
```

## Development

```bash
# Edit PicoRuby apps
vim src_components/R2P2-ESP32/storage/home/otmeiwa.rb

# Build and flash
rake build APP=otmeiwa && rake flash

# Monitor serial frames
rake monitor

# Edit web synth
vim web/index.html
vim web/src/ruby/sensor_mapper.rb
```

**Common Tasks**:
```bash
rake -T            # List all available rake tasks
rake check_env     # Verify ESP-IDF environment
rake monitor       # Show device serial output (Ctrl+C to exit)
rake cleanbuild    # Full rebuild (slow but thorough)
```

## Performance

- **Serial output rate**: ~20fps (50ms loop)
- **Web Audio latency**: <20ms (setTargetAtTime smooth transitions)
- **MIDI latency**: <10ms (IRQ-based)
- **Memory**: ~200KB used (ESP32: 520KB available)

## Troubleshooting

**Web Serial not connecting**:
1. Use Chrome (Web Serial API required)
2. Verify ATOM Matrix appears as serial device
3. Confirm baud rate: 115200

**No serial frames from otmeiwa.rb**:
1. Run `rake monitor` - confirm `<D:...,AX:...,AY:...,AZ:...>` output
2. Check I2C connections (GPIO25=SDA, GPIO21=SCL)
3. VL53L0X I2C address: 0x29

**Distance sensor not responding**:
1. Check I2C connections
2. Verify I2C address: 0x29 (VL53L0X default)

**MIDI not working (otma)**:
1. Verify GPIO22 (TX) and GPIO19 (RX) connections
2. Confirm MIDI Unit baudrate: 31250

**PWM speaker silent (otpwm)**:
1. Check GPIO33 connection
2. Verify duty cycle 25-60%

## References

- [M5 ATOM Matrix Documentation](https://docs.m5stack.com/en/core/atom_matrix)
- [PicoRuby Docs](https://picoruby.org/)
- [R2P2-ESP32 Repository](https://github.com/picoruby/R2P2-ESP32)
- [Web Serial API (MDN)](https://developer.mozilla.org/en-US/docs/Web/API/Web_Serial_API)
- [Web Audio API (MDN)](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)
- [ruby.wasm](https://ruby.github.io/ruby.wasm/)
- [VL53L0X Distance Sensor](https://www.st.com/en/imaging-and-motion/vl53l0x.html)

## License

Educational examples for PicoRuby development on ESP32.
