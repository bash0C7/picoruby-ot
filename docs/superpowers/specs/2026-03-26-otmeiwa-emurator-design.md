# otmeiwa_emurator Design Spec

Date: 2026-03-26

## Overview

A standalone HTML page (`web/otmeiwa_emurator.html`) that emulates the ATOM Matrix sensor (otmeiwa.rb) behavior via browser-only Web Serial API. Enables full synth testing without physical hardware. Zero changes to `index.html`.

## Architecture

```
[otmeiwa_emurator.html]               [index.html]
  Slider UI (D/AX/AY/AZ)
  ruby.wasm (EmulatorApp)
  JS.global.serialWrite(frame)
  Web Serial WRITE
  /dev/ttys003 ──────────────────────── /dev/ttys004
               Ruby PTY bridge                ↑
               (server.rb thread)      Web Serial READ
                                       rubySerialOnReceive(data)
                                       ruby.wasm (SynthApp)
                                       → sound output
```

### Virtual Serial Bridge (server.rb)

`server.rb` creates a PTY pair on startup using Ruby's `PTY` module. A background thread relays data from master1 to master2. No socat or external tools required.

```
rake web
  → "Emulator port: /dev/ttys003"
  → "Synth port:    /dev/ttys004"
```

## Serial Protocol

Frame format (identical to otmeiwa.rb):
```
<D:NNN,AX:NNN,AY:NNN,AZ:NNN>\n
```

Ranges:
- D: 20–900 (mm)
- AX/AY/AZ: -1000–+1000 (accel × 1000, calibration-offset)

Send rate: ~20fps (50ms interval)

## File Structure

New files only — index.html unchanged:

```
web/
├── otmeiwa_emurator.html          (new)
├── server.rb                      (extended: PTY bridge)
└── src/ruby/emulator/
    ├── emulator_app.rb            (new)
    └── frame_generator.rb         (new)
```

## UI Design

Same CSS design system as index.html (dark theme, monospace, green accent `#0f0`, teal `#0cc`). Responsive via existing flex/max-width patterns.

```
picoruby-ot Emurator (otmeiwa)
┌─ SERIAL ─────────────────────────────┐
│ [Connect] [Disconnect]  115200       │
│ ● disconnected                       │
└──────────────────────────────────────┘
┌─ SENSOR CONTROLS ────────────────────┐
│ Distance mm  [────●──────]  450      │
│ AX           [───●───────]    0      │
│ AY           [───●───────]    0      │
│ AZ           [───●───────]    0      │
└──────────────────────────────────────┘
┌─ FRAME MONITOR ──────────────────────┐
│ <D:450,AX:0,AY:0,AZ:0>              │
└──────────────────────────────────────┘
```

## Ruby Code (ruby.wasm — main logic)

### frame_generator.rb

```ruby
module FrameGenerator
  def self.build(d, ax, ay, az)
    "<D:#{d},AX:#{ax},AY:#{ay},AZ:#{az}>\n"
  end
end
```

### emulator_app.rb

```ruby
class EmulatorApp
  def initialize
    @connected = false
  end

  def register_callbacks
    app = self
    JS.global[:rubyTick]                 = lambda { app.tick }
    JS.global[:rubyEmulatorOnConnect]    = lambda { app.on_connect }
    JS.global[:rubyEmulatorOnDisconnect] = lambda { app.on_disconnect }
  end

  def on_connect    = @connected = true
  def on_disconnect = @connected = false

  def tick
    return unless @connected
    d  = JS.global[:emD].to_i
    ax = JS.global[:emAX].to_i
    ay = JS.global[:emAY].to_i
    az = JS.global[:emAZ].to_i
    frame = FrameGenerator.build(d, ax, ay, az)
    JS.global.serialWrite(frame)
    JS.global.updateFrameMonitor(frame.strip)
  end
end
```

## JS Glue (minimal)

- `serialConnect()` — `navigator.serial.requestPort()` → `port.open()` → `port.writable.getWriter()`
- `serialDisconnect()` — cancel writer, close port
- `serialWrite(data)` — `writer.write(new TextEncoder().encode(data))` (called from Ruby)
- `setInterval(() => { if(window.rubyTick) window.rubyTick() }, 50)` — 20fps tick
- Slider `oninput` — sets `window.emD`, `window.emAX`, `window.emAY`, `window.emAZ`

## server.rb Changes

```ruby
require 'pty'

# Create virtual serial bridge on startup
master1, slave1 = PTY.open
master2, slave2 = PTY.open
puts "Emulator port: #{slave1.path}"
puts "Synth port:    #{slave2.path}"

Thread.new do
  loop do
    begin
      data = master1.read_nonblock(256)
      master2.write(data)
    rescue IO::WaitReadable
      IO.select([master1], nil, nil, 0.01)
    rescue
      break
    end
  end
end
```

## Usage

```bash
rake web
# → Emulator port: /dev/ttys003
# → Synth port:    /dev/ttys004

# 1. Open otmeiwa_emurator.html → Connect to /dev/ttys003
# 2. Open index.html → Connect to /dev/ttys004 → Init Audio
# 3. Move sliders → sound output
```

## Constraints

- Chrome only (Web Serial API)
- localhost or HTTPS required
- User gesture required for both serial connect and audio init
- index.html: zero changes
