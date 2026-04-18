---
name: sensor-serial
description: Sensor serial protocol for otmeiwa → Chrome synth data flow. Use when debugging serial frames, checking protocol format, or troubleshooting Web Serial connection.
user-invocable: false
---

# Sensor Serial Protocol Reference

## Protocol Format

```
<D:NNNN,AX:NNNN,AY:NNNN,AZ:NNNN>\n
```

Fields:
- `D`: distance mm, range 20–900 (EMA-smoothed alpha=50 on PicoRuby side)
- `AX/AY/AZ`: accel delta from calibration baseline (signed integer)
- Delimiter: `<...>\n` (angle brackets + newline)
- Rate: ~20fps (50ms PicoRuby loop)
- Baud: 115200 bps

## PicoRuby Side (otmeiwa.rb)

```ruby
# Frame send (UART0/USB via puts)
puts "<D:#{@distance},AX:#{@ax},AY:#{@ay},AZ:#{@az}>"

# Accel calibration: button press snapshots baseline
# Sent values = current_accel - baseline (relative hand motion)

# Distance: out-of-range clamp
# 8190 (VL53L0X max) → treated as DIST_VALID_MAX (900)
```

## Web Side Parser (serial_protocol.rb)

```ruby
SENSOR_FRAME_PATTERN = /\<D:(-?\d+),AX:(-?\d+),AY:(-?\d+),AZ:(-?\d+)\>/

SerialProtocol.extract_frames(buffer)
# → [frames_array, remaining_buffer]
# frames_array: [{distance:, ax:, ay:, az:}, ...]
```

## Sensor → Synth Mapping (sensor_mapper.rb)

```ruby
# Distance → frequency (logarithmic scale)
FREQ_MIN = 40Hz, FREQ_MAX = 2000Hz
DIST_MIN = 20mm, DIST_MAX = 900mm
freq = FREQ_MIN * (freq_ratio ** normalized_dist)

# Accel → FM depth (0.0–1.0)
depth = (ax.abs + ay.abs + az.abs) / accel_scale  # clamped to 1.0
```

## Web Serial (Chrome)

```javascript
// Connect (115200 baud)
port = await navigator.serial.requestPort();
await port.open({ baudRate: 115200 });
reader = port.readable.pipeThrough(new TextDecoderStream()).getReader();

// Read loop
while (true) {
  const { value, done } = await reader.read();
  rubySerialOnReceive(value);  // → Ruby SerialManager#receive_data
}
```

Requirements:
- Chrome only (Web Serial API)
- HTTPS or localhost
- User must click "Connect" (no auto-connect)
- ATOM Matrix must appear as serial device

## Troubleshooting

| Symptom | Check |
|---------|-------|
| No frames in Chrome | Run `rake monitor` — confirm frames appear |
| `<D:8190,...>` | VL53L0X out of range — move hand closer |
| `<D:0,...>` | Sensor not init — check I2C GPIO25/21 |
| Chrome won't connect | Use Chrome (not Safari/Firefox), check port permissions |
| Frames garbled | Baud mismatch (should be 115200 both sides) |
| AX/AY/AZ always 0 | Button not pressed — press to calibrate accel baseline |

## LED Feedback (otmeiwa.rb)

- 15 LEDs on GPIO26
- Hue: distance 20–900mm → 0–383 (full spectrum)
- Saturation: accel Manhattan magnitude → 100–255
- Brightness: active=150, muted=20 (grey, sat=0)
- Button toggles active + calibrates accel baseline on activation
