require 'js'

$serial   = Serial.new
$mapper   = SensorMapper.new
$presets  = PresetManager.new

class SynthApp
  def initialize(serial, mapper, presets)
    @serial  = serial
    @mapper  = mapper
    @presets = presets
  end

  def register_callbacks
    app = self
    JS.global[:rubySerialOnConnect]    = lambda { |baud| app.on_connect(baud) }
    JS.global[:rubySerialOnDisconnect] = lambda { app.on_disconnect }
    JS.global[:rubySerialOnReceive]    = lambda { |data| app.on_receive(data) }
    JS.global[:rubyOnParamUpdate]      = lambda { |key, value| app.on_param(key.to_s, value) }
  end

  def on_connect(baud)
    baud_i = baud.to_i
    @serial.on_connect(baud_i)
    JS.global.updateSerialStatus("connected at #{baud_i}bps", @serial.parse_error_count)
  end

  def on_disconnect
    @serial.on_disconnect
    JS.global.updateSensorParams(220, 0.0, 0)
    JS.global.updateSerialStatus("disconnected", @serial.parse_error_count)
  end

  def on_receive(data)
    frames = @serial.receive(data.to_s)
    return if frames.empty?
    frames.each do |frame|
      next unless frame
      dist     = frame[:distance]
      ax       = frame[:ax]
      ay       = frame[:ay]
      az       = frame[:az]
      note     = @mapper.distance_to_note(dist)
      freq     = @mapper.note_to_freq(note)
      note_str = @mapper.note_name(note)
      fm_depth = @mapper.accel_to_fm_depth(ax, ay, az)
      active   = @mapper.in_range?(dist)
      JS.global.updateSensorParams(freq, fm_depth, active ? 1 : 0)
      JS.global.updateSensorDisplay(dist, ax, ay, az, freq, fm_depth, note_str)
    end
    JS.global.updateSerialMonitor(@serial.rx_log.last.to_s)
  end

  def on_param(key, value)
    case key
    when 'preset'       then @presets.switch(value.to_s)
    when 'scale'        then @mapper.set_scale(value.to_s)
    when 'glide_time'   then JS.global[:synthGlideTime] = value.to_f / 1000.0
    when 'fm_depth_manual' then JS.global[:synthFmDepthManual] = value.to_f
    when 'mod_ratio'    then JS.global[:synthModRatio] = value.to_f
    when 'carrier_wave' then @presets.patch[:fm_carrier]&.set_param(:waveform, value.to_s)
    when 'mod_wave'     then @presets.patch[:fm_mod]&.set_param(:waveform, value.to_s)
    when 'dist_min'     then @mapper.set_dist_range(value.to_i, @mapper.dist_max)
    when 'dist_max'     then @mapper.set_dist_range(@mapper.dist_min, value.to_i)
    when 'midi_min'     then @mapper.set_midi_range(value.to_i, @mapper.midi_max)
    when 'midi_max'     then @mapper.set_midi_range(@mapper.midi_min, value.to_i)
    when 'accel_scale'  then @mapper.accel_scale = value.to_f
    when 'filter_cutoff' then @presets.patch[:filter]&.set_param(:cutoff, value.to_f)
    when 'filter_q'     then @presets.patch[:filter]&.set_param(:q, value.to_f)
    when 'master_gain'  then JS.global[:synthMasterGain] = value.to_f
    when 'attack'       then @presets.patch&.set_attack(value.to_f / 1000.0)
    when 'decay'        then @presets.patch&.set_decay(value.to_f / 1000.0)
    when 'sustain'      then @presets.patch&.set_sustain(value.to_f)
    when 'release'      then @presets.patch&.set_release(value.to_f / 1000.0)
    end
  end
end

# 初期化失敗はプログラムエラーなので握りつぶさずそのまま上げる
JS.global[:console].log("[Ruby] starting picoruby-ot synth...")
app = SynthApp.new($serial, $mapper, $presets)
app.register_callbacks
JS.global[:console].log("[Ruby] picoruby-ot synth ready!")
