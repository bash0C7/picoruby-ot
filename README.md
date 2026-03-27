# picoruby-ot: びことん

A software musical instrument inspired by Maywa Denki's Otamatone.

Distance sensor controls pitch. Shake the stick for FM synthesis effects.
Built with M5 ATOM Matrix (ESP32) + PicoRuby + Chrome Web Audio.

## Hardware

- M5 ATOM Matrix (ESP32-PICO-D4)
- Unit ToF (VL53L0X laser distance sensor)
- USB cable to PC running Chrome

## How it works

1. Flash `otmeiwa.rb` to ATOM Matrix via R2P2-ESP32
2. Open `web/index.html` in Chrome (serve with `cd web && ruby -run -ehttpd . -p8000`)
3. Click Connect, select the ATOM Matrix serial port (115200bps)
4. Hold the sensor and move your hand — distance controls pitch

## Architecture

```
ATOM Matrix (otmeiwa.rb)
  VL53L0X distance sensor → USB Serial 115200bps
    ↓ <D:NNNN,AX:NNNN,AY:NNNN,AZ:NNNN>
Chrome (web/index.html)
  ruby.wasm → SensorMapper → FM Synthesizer (Web Audio API)
```

## Build

See `src_components/R2P2-ESP32/CLAUDE.md` for build instructions.
Requires: ESP-IDF toolchain, R2P2-ESP32 firmware.
