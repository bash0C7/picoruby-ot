require 'ws2812'
require 'gpio'
require 'irq'
require 'i2c'
require 'mpu6886'
require 'vl53l0x'

class SensorLEDVisualizer
  LED_PIN   = 32
  LED_COUNT = 16
  DIST_MIN = 20
  DIST_MAX = 900

  def initialize(led_strip)
    @led_strip = led_strip
    @led_colors = Array.new(LED_COUNT, 0)
  end

  def update(distance, ax, ay, az, sound_on)
    if sound_on
      # 色相: 距離 20-900mm → 0-383
      hue = ((distance - DIST_MIN) * 384 / (DIST_MAX - DIST_MIN)).clamp(0, 383)
      # 彩度: 加速度マンハッタン距離 → 100-255
      mag = ax.abs + ay.abs + az.abs
      saturation = (mag * 155 / 1500 + 100).clamp(100, 255)
      brightness = 150
    else
      # ミュート時: 暗いグレー
      hue = 0
      saturation = 0
      brightness = 20
    end

    LED_COUNT.times do |i|
      sb = (saturation << 8) | brightness
      @led_colors[i] = (hue << 16) | sb
    end
  end

  def show
    @led_strip.show_hsb_hex(*@led_colors)
  end

  def flash
    @led_strip.flash!(LED_COUNT)
  end
end

class SensorInstrument
  I2C_SDA_PIN = 25
  I2C_SCL_PIN = 21
  DIST_VALID_MIN = 20
  DIST_VALID_MAX = 900
  DISTANCE_SMOOTH_ALPHA = 50

  attr_reader :distance, :ax, :ay, :az, :sound_on

  def initialize(tof_sensor, accel_sensor)
    @tof_sensor = tof_sensor
    @accel_sensor = accel_sensor
    @distance = DIST_VALID_MIN
    @prev_distance = DIST_VALID_MIN
    @ax = 0
    @ay = 0
    @az = 0
    @accel_baseline_x = 0
    @accel_baseline_y = 0
    @accel_baseline_z = 0
    @sound_on = false
  end

  def toggle_sound
    @sound_on = !@sound_on
    if @sound_on
      # キャリブレーション: 現在の加速度をベースラインとして記録
      raw = @accel_sensor.acceleration
      @accel_baseline_x = raw[:x]
      @accel_baseline_y = raw[:y]
      @accel_baseline_z = raw[:z]
    end
  end

  def update
    # 距離計測
    raw_distance = @tof_sensor.read_distance
    if raw_distance >= DIST_VALID_MIN && raw_distance <= DIST_VALID_MAX
      # EMAで平滑化
      delta = raw_distance - @prev_distance
      @distance = (@prev_distance + delta * DISTANCE_SMOOTH_ALPHA / 100).to_i
      @prev_distance = @distance
    end

    # 加速度計測 (baseline差分、milliG整数変換)
    raw = @accel_sensor.acceleration
    @ax = ((raw[:x] - @accel_baseline_x) * 1000).to_i
    @ay = ((raw[:y] - @accel_baseline_y) * 1000).to_i
    @az = ((raw[:z] - @accel_baseline_z) * 1000).to_i
  end

  def send_frame
    puts "<D:#{@distance},AX:#{@ax},AY:#{@ay},AZ:#{@az}>"
  end
end

button = GPIO.new(39, GPIO::IN|GPIO::PULL_UP)
led_strip = WS2812.new(RMTDriver.new(SensorLEDVisualizer::LED_PIN))

i2c_bus = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: SensorInstrument::I2C_SDA_PIN, scl_pin: SensorInstrument::I2C_SCL_PIN)
sleep_ms(100)

accel_sensor = MPU6886.new(i2c_bus)
sleep_ms(100)
accel_sensor.accel_range = MPU6886::ACCEL_RANGE_2G
sleep_ms(100)

tof_sensor = VL53L0X.new(i2c_bus)
sleep_ms(100)

instrument = SensorInstrument.new(tof_sensor, accel_sensor)
led_viz = SensorLEDVisualizer.new(led_strip)

irq = button.irq(GPIO::EDGE_FALL, debounce: 100, capture: {inst: instrument, viz: led_viz}) do |btn, ev, cap|
  cap[:inst].toggle_sound
  cap[:viz].flash
end

loop do
  IRQ.process
  instrument.update
  instrument.send_frame
  led_viz.update(instrument.distance, instrument.ax, instrument.ay, instrument.az, instrument.sound_on)
  led_viz.show
  sleep_ms(50)
end

irq.unregister
