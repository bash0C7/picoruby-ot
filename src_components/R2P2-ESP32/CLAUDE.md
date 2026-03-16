# PicoRuby/mruby Embedded Development — ATOM Matrix (ESP32-PICO-D4)

Always-needed knowledge for editing `.rb` files in `storage/home/`.

## PicoRuby Constraints (Critical)

### Prohibited Methods

```ruby
# NEVER use these in PicoRuby:
defined?(x)         # → explicit nil check instead
Hash#fetch          # → hash[key] with nil check
String#reverse      # → not supported
String#rjust        # → not supported
inline rescue       # x = foo rescue bar  → use if/else
proc { }            # → use blocks directly or lambda
lambda { }          # → limited support; avoid
Math.sqrt           # → use integer approximation if needed
```

### Safe Patterns

```ruby
# nil check (instead of defined?)
val = obj.method_name
return unless val

# Hash access (instead of fetch)
val = hash[:key]
return unless val

# Integer math preferred
mag = ax.abs + ay.abs + az.abs   # Manhattan distance (no sqrt needed)
```

## Available Libraries (mrbgems)

```ruby
require 'i2c'       # I2C bus communication
require 'vl53l0x'   # ToF distance sensor (Unit ToF)
require 'imu'       # MPU6886 accelerometer/gyro (internal)
require 'uart'      # UART serial communication
require 'ws2812'    # WS2812 LED strip via RMT
require 'irq'       # GPIO interrupt request handling
require 'gpio'      # GPIO input/output
```

## Hardware API Reference

### I2C + VL53L0X (Distance Sensor)

```ruby
i2c = I2C.new(:ESP32_I2C0, sda_pin: 25, scl_pin: 21, frequency: 400_000)
tof = VL53L0X.new(i2c)
tof.start_continuous(0)
distance = tof.read  # mm (returns 8190 on out-of-range)
```

### MPU6886 (Accelerometer/Gyro — Internal)

```ruby
imu = IMU.new(:ESP32_I2C0, sda_pin: 25, scl_pin: 21)
raw = imu.accel  # Array: [x, y, z] as integers (raw ADC values)
```

### WS2812 LED Strip

```ruby
rmt = RMTDriver.new(26)            # GPIO pin
led = WS2812.new(rmt)
colors = Array.new(15, 0)          # Pre-allocate (avoid dynamic alloc)
colors[0] = (r << 16) | (g << 8) | b
led.show_hex(*colors)              # Splat array
```

### UART (Serial Output to PC)

```ruby
# UART0 = USB (Serial to Chrome / monitor)
puts "<D:#{dist},AX:#{ax},AY:#{ay},AZ:#{az}>"  # UART0 via puts

# UART1 = MIDI (external MIDI module)
uart = UART.new(:ESP32_UART1, baudrate: 31250, tx_pin: 22, rx_pin: 19)
uart.write((0x99).chr + note.chr + vel.chr)
```

### GPIO Button (GPIO 39)

```ruby
btn = GPIO.new(39, GPIO::IN | GPIO::PULL_UP)
irq = btn.irq(GPIO::EDGE_FALL, debounce: 50) do |pin, event|
  handle_button_press
end
loop do
  IRQ.process
  sleep_ms(50)
end
```

## GPIO Mapping (This Project)

| Function       | GPIO | App        | Notes                  |
|----------------|------|------------|------------------------|
| Button         | 39   | All        | Built-in, PULL_UP      |
| I2C SDA        | 25   | otpwm/otmeiwa | J3 port             |
| I2C SCL        | 21   | otpwm/otmeiwa | J3 port             |
| PWM Speaker    | 33   | otpwm      | J4 port                |
| WS2812 LED     | 26   | otpwm/otmeiwa | Grove port          |
| WS2812 LED     | 22   | otma       | PortD/J5               |
| MIDI TX        | 22   | otma       | UART1, PortD/J5        |
| MIDI RX        | 19   | otma       | UART1, PortD/J5        |
| UART0 (USB)    | —    | otmeiwa    | Serial to Chrome       |

## Serial Protocol (otmeiwa → Chrome)

```
<D:NNNN,AX:NNNN,AY:NNNN,AZ:NNNN>\n
```

- `D`: distance mm (20–900), EMA-smoothed (alpha=50)
- `AX/AY/AZ`: accel delta from calibration baseline (signed int)
- Rate: ~20fps (50ms loop)
- Baud: 115200 (UART0/USB)

## Code Style Rules

- Shallow nesting only (memory = 520KB, stack limited)
- Pre-allocate arrays: `arr = Array.new(N, 0)` at init
- No dynamic string building in loops (use pre-built format strings)
- Integer math over float where possible
- Comments: Japanese, 体言止め style

## App File Locations

```
storage/home/
├── otma.rb      # MIDI auto drum machine
├── otpwm.rb     # PWM speaker + distance sensor
└── otmeiwa.rb   # Serial sensor output → Chrome synth
```
