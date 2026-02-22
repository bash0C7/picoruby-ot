# picoruby-ot: ATOM Matrix Instrument Project

A PicoRuby (R2P2-ESP32) application for **M5 ATOM Matrix (ESP32-PICO-D4)** featuring two interactive musical instruments: automatic MIDI drum machine and distance sensor synthesizer.

## Overview

**picoruby-ot** provides two complementary instruments running on ATOM Matrix:

### otma.rb - Auto Drum Machine
- **Automatic rhythm playback** via MIDI sound synthesis
- **16-step drum patterns** with kick, snare, hi-hats, toms, claps
- **Real-time MIDI output** (31250 bps) to external sound module
- **Synchronized LED visualization** reflecting drum group history
- **Button control** for crash cymbal triggering

### otpwm.rb - Distance Sensor Instrument
- **Distance-to-frequency mapping** (20mm-300mm → 200Hz-1000Hz)
- **Accelerometer-driven sound modulation** (duty cycle and vibrato)
- **VL53L0X ToF sensor** for responsive pitch control
- **WS2812 LED strip** with dynamic color response to sound
- **Ambient visualization** with smooth wave-like LED patterns

### otv.rb - Distance Sensor UART Visualizer
- Distance-to-frequency mapping (20mm-300mm -> 200Hz-1000Hz, same as otpwm.rb)
- UART output instead of PWM: sends <F:NNNNN,D:NNN> frames to Chrome via USB Serial
- WS2812 LED strip visualization (same as otpwm.rb)
- Use with ruby_sound_visualizer for Chrome Web Audio API PWM tone playback
- Button toggles mute (UART send on/off)

## Hardware

**Device**: M5 ATOM Matrix (ESP32-PICO-D4)

**Configuration**:
```
┌─────────────────────┐
│  ATOM Matrix        │
├─────────────────────┤
│ GPIO39 (built-in)   │ ──→ Button (both apps)
│ GPIO21/25 (J3)      │ ──→ I2C bus (otpwm)
│ GPIO22/19 (PortD)   │ ──→ MIDI UART (otma)
│ GPIO33 (J4)         │ ──→ PWM Speaker (otpwm)
│ GPIO26/22           │ ──→ WS2812 LED control
└─────────────────────┘
```

**External Sensors** (otpwm.rb):
- VL53L0X (Unit ToF) - Distance measurement
- MPU6886 (internal) - Accelerometer/gyro

**External Components** (otma.rb):
- MIDI Unit (SAM2695 or compatible) - Sound module

## File Structure

```
picoruby-ot/
├── src_components/R2P2-ESP32/
│   ├── storage/home/
│   │   ├── otma.rb              # Auto drum machine
│   │   ├── otpwm.rb             # Distance sensor instrument
│   │   └── otv.rb               # Distance sensor UART visualizer (for Chrome audio)
│   └── components/picoruby-esp32/
│       └── picoruby/build_config/
│           └── xtensa-esp.rb     # Xtensa (ESP32) build config
├── Rakefile                      # Build automation
├── CLAUDE.md                     # Project development guidelines
├── README.md                     # This file
└── .gitignore                    # Git exclusions
```

## Quick Start

**Prerequisites**:
- ESP-IDF installed at `$HOME/esp/esp-idf/`
- Homebrew with OpenSSL (macOS)
- M5 ATOM Matrix device

**Setup**:
```bash
# Step 1: Initialize project and build environment
rake init

# Step 2: Build otma (auto drum)
rake build APP=otma

# Step 3: Flash to ATOM Matrix
rake flash

# Step 4: Monitor serial output
rake monitor
```

**For otpwm** instead:
```bash
rake build APP=otpwm
rake flash
```

## Usage

### otma.rb (Auto Drum Machine)

1. Flash `otma.rb` to ATOM Matrix
2. Connect MIDI Unit to PortD/J5 (GPIO22=TX, GPIO19=RX)
3. Connect MIDI cable from Unit to sound module
4. Power on - automatic drum pattern playback begins
5. Press button to trigger crash cymbal
6. Watch LEDs respond to rhythm pattern

**MIDI Configuration**:
- Baud: 31250 (standard MIDI)
- Channel: 10 (drums)
- Notes: KICK=36, SNARE=38, HI_HAT=42/46, TOMS=41/47/50, CLAP=39, CRASH=49

### otpwm.rb (Distance Sensor Instrument)

1. Flash `otpwm.rb` to ATOM Matrix
2. Connect sensors via J3 (I2C: GPIO25=SDA, GPIO21=SCL)
   - VL53L0X ToF sensor (Unit ToF)
   - MPU6886 accelerometer (internal)
3. Connect PWM speaker to J4 (GPIO33)
4. Connect WS2812 LED strip (30 LEDs)
5. Power on - move hand near sensor
6. Distance changes pitch; tilt device for sound modulation
7. Press button to mute/unmute

### otv.rb (UART Visualizer for Chrome)

1. Flash `otv.rb` to ATOM Matrix
2. Connect sensors via J3 (I2C: GPIO25=SDA, GPIO21=SCL) — same as otpwm.rb
3. Connect USB to Mac running Chrome
4. Open ruby_sound_visualizer, connect Web Serial
5. Move hand near ToF sensor — Chrome plays PWM tone via Web Audio API
6. Press button to mute/unmute UART frequency output

**Sensor Ranges**:
- Distance: 20mm (low tone) to 300mm (high tone)
- Frequency: 200Hz to 1000Hz
- Duty: 25% to 60%
- LED count: 30 pixels with wave animation

## LED Visualization

### otma.rb
- **Idle**: Dim gray
- **On Beat**: Full brightness color based on drum group
- **Color Mapping**:
  - Group 1 (KICK): Red (0°)
  - Group 2 (SNARE): Cyan (128°)
  - Group 3 (CLAP): Magenta (192°)
  - Group 4 (TOM): Yellow (64°)

### otpwm.rb
- **Distance bands**: Different hues per distance range
- **Frequency response**: Color hue follows pitch
- **Duty modulation**: Brightness reflects volume
- **Wave animation**: Flowing LED pattern

## Development

**Edit applications**:
```bash
# Modify the application
vim src_components/R2P2-ESP32/storage/home/otma.rb
vim src_components/R2P2-ESP32/storage/home/otpwm.rb

# Build and flash
rake build APP=otma && rake flash
```

**Common Tasks**:
```bash
rake -T            # List all available rake tasks
rake check_env     # Verify ESP-IDF environment
rake monitor       # Show device serial output (Ctrl+C to exit)
rake cleanbuild    # Full rebuild (slow but thorough)
```

## Architecture

```
picoruby-ot (PicoRuby/mruby applications)
├── otma.rb
│   ├── DrumMachine: MIDI pattern playback, LED group tracking
│   ├── RhythmLEDVisualizer: Pattern-synchronized LED colors
│   └── UART MIDI (GPIO22/19 @ 31250 bps)
│
├── otpwm.rb
│   ├── NoiseInstrument: Distance/accel → frequency/duty mapping
│   ├── AmbientLEDVisualizer: Sound-responsive LED patterns
│   ├── VL53L0X (ToF distance)
│   ├── MPU6886 (accelerometer)
│   ├── PWM Speaker (GPIO33)
│   └── WS2812 LED Strip (30 pixels)
│
└── otv.rb
    ├── NoiseInstrument: Distance -> frequency/duty mapping (reused from otpwm.rb)
    ├── AmbientLEDVisualizer: LED visualization (reused from otpwm.rb)
    ├── UARTSender: UART <F:NNN,D:NNN> frame output (replaces PWM)
    └── WS2812 LED Strip (GPIO26)
```

## Performance

- **Latency**: <10ms (IRQ-based)
- **Memory**: ~200KB used (ESP32: 400KB available)
- **MIDI Update**: Every 2-12ms (configurable)
- **LED Update**: Every 1-4ms

## Troubleshooting

**Serial connection fails**:
```bash
# Identify device port
ls /dev/cu.usbserial*

# Set explicit port
ESPPORT=/dev/cu.usbserial-XXXXXX rake monitor
```

**MIDI not working**:
1. Verify GPIO22 (TX) and GPIO19 (RX) connections
2. Confirm MIDI Unit baudrate: 31250
3. Test with external MIDI monitor on host computer

**Distance sensor not responding**:
1. Check I2C connections (GPIO25=SDA, GPIO21=SCL)
2. Verify I2C address: 0x29 (VL53L0X default)
3. Enable DEBUG mode in otpwm.rb to see sensor values

**Sound not coming through PWM speaker**:
1. Check GPIO33 connection
2. Verify duty cycle values in otpwm.rb (25-60%)
3. Confirm speaker impedance (Grove compatible)

## References

- [M5 ATOM Matrix Documentation](https://docs.m5stack.com/en/core/atom_matrix)
- [PicoRuby Docs](https://picoruby.org/)
- [R2P2-ESP32 Repository](https://github.com/picoruby/R2P2-ESP32)
- [MIDI Specification](https://en.wikipedia.org/wiki/MIDI)
- [VL53L0X Distance Sensor](https://www.st.com/en/imaging-and-motion/vl53l0x.html)

## License

Educational examples for PicoRuby development on ESP32.
