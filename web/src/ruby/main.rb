require 'js'

$serial = SerialManager.new
$mapper = SensorMapper.new
$patch = SynthPatch.build(adapter: SynthPatch::WebAdapter.new) do |syn|
  mod     = syn.fm_op(:sine, freq: 220, amp: 50, name: :fm_mod)
  carrier = syn.fm_op(:sine, freq: 220, name: :fm_carrier)
  carrier.fm(mod)
  syn.mix(carrier, name: :mixer)
     .filter(:lowpass, cutoff: 800, q: 1.2, name: :filter)
     .gain(0.4, name: :master)
     .out
end

class SynthApp
  def initialize(serial, mapper, patch)
    @serial = serial
    @mapper = mapper
    @patch = patch
    @was_active = false
  end

  def register_callbacks
    app = self

    JS.global[:rubySerialOnConnect] = lambda do |baud|
      app.on_serial_connect(baud)
    end

    JS.global[:rubySerialOnDisconnect] = lambda do
      app.on_serial_disconnect
    end

    JS.global[:rubySerialOnReceive] = lambda do |data|
      app.on_serial_receive(data)
    end

    JS.global[:rubyOnParamUpdate] = lambda do |key, value|
      app.on_param_update(key.to_s, value.to_f)
    end
  end

  def on_serial_connect(baud)
    @serial.on_connect(baud.to_i)
    JS.global.updateSerialStatus("connected at #{baud}bps")
  end

  def on_serial_disconnect
    @serial.on_disconnect
    @was_active = false
    JSBridge.update_synth_params(220, 0.0, false)
    JS.global.updateSerialStatus("disconnected")
  end

  def on_serial_receive(data)
    frames = @serial.receive_data(data.to_s)
    return unless frames && !frames.empty?

    frames.each do |frame|
      next unless frame

      dist  = frame[:distance]
      ax    = frame[:ax]
      ay    = frame[:ay]
      az    = frame[:az]
      freq  = @mapper.distance_to_freq(dist)
      fm_depth = @mapper.accel_to_fm_depth(ax, ay, az)
      active = @mapper.in_range?(dist)

      JSBridge.update_synth_params(freq, fm_depth, active)
      JSBridge.update_sensor_display(dist, ax, ay, az, freq, fm_depth)

      last_line = @serial.rx_log.last
      JS.global.updateSerialMonitor(last_line.to_s) if last_line

      @was_active = active
    end
  end

  def on_param_update(key, value)
    case key
    when 'dist_min'
      @mapper.set_ranges(value.to_i, @mapper.dist_max, @mapper.freq_min, @mapper.freq_max)
    when 'dist_max'
      @mapper.set_ranges(@mapper.dist_min, value.to_i, @mapper.freq_min, @mapper.freq_max)
    when 'freq_min'
      @mapper.set_ranges(@mapper.dist_min, @mapper.dist_max, value.to_i, @mapper.freq_max)
    when 'freq_max'
      @mapper.set_ranges(@mapper.dist_min, @mapper.dist_max, @mapper.freq_min, value.to_i)
    when 'accel_scale'
      @mapper.accel_scale = value
    when 'filter_cutoff'
      @patch[:filter]&.set_param(:cutoff, value)
    when 'filter_q'
      @patch[:filter]&.set_param(:q, value)
    when 'master_gain'
      JS.global[:synthMasterGain] = value
    when 'attack'
      @patch.set_attack(value / 1000.0)
    when 'decay'
      @patch.set_decay(value / 1000.0)
    when 'sustain'
      @patch.set_sustain(value)
    when 'release'
      @patch.set_release(value / 1000.0)
    end
  end
end

begin
  JSBridge.log("Ruby VM started, initializing picoruby-ot synth...")

  app = SynthApp.new($serial, $mapper, $patch)
  app.register_callbacks

  JSBridge.log("picoruby-ot synth ready!")
rescue => e
  JSBridge.error("Fatal error: #{e.message}")
end
