require 'js'

class SynthApp
  def initialize(serial, mapper, presets)
    @serial  = serial
    @mapper  = mapper
    @presets = presets
    @adapter = nil
    @glide_sec = 0.005
    @attack = 0.01
    @release = 0.2
    @volume = 0.4
  end

  def init_audio
    @adapter = SynthPatch::WebAdapter.new
    @adapter.init_audio
    @presets.set_adapter(@adapter)
    @presets.switch(:otamatone)
    JS.global[:console].log("[Ruby] Audio initialized")
    # オーディオ状態UI更新
    ast = JS.global[:document].querySelector("#ast")
    if ast
      ast[:textContent] = "audio on"
      ast[:className] = "st"
    end
  end

  def register_callbacks
    app = self
    JS.global[:rubySerialOnConnect]    = lambda { |baud| app.on_connect(baud) }
    JS.global[:rubySerialOnDisconnect] = lambda { app.on_disconnect }
    JS.global[:rubySerialOnReceive]    = lambda { |data| app.on_receive(data) }
    JS.global[:rubyOnParamUpdate]      = lambda { |key, value| app.on_param(key.to_s, value) }
    JS.global[:rubyInitAudio]          = lambda { app.init_audio }
  end

  def on_connect(baud)
    baud_i = baud.to_i
    @serial.on_connect(baud_i)
    # シリアル状態UI更新
    update_serial_status("connected at #{baud_i}bps", @serial.parse_error_count)
  end

  def on_disconnect
    @serial.on_disconnect
    # ゲインゼロへフェードアウト
    @adapter&.update_gain(0.0, @release)
    update_serial_status("disconnected", @serial.parse_error_count)
  end

  def on_receive(data)
    frames = @serial.receive(data.to_s)
    return if frames.empty?
    frames.each do |frame|
      next unless frame
      update(frame[:distance], frame[:ax], frame[:ay], frame[:az])
    end
    # シリアルモニター更新
    update_serial_monitor(@serial.rx_log.last.to_s)
  end

  # ステートレス更新 — 毎フレーム同じ処理、分岐なし
  def update(dist_mm, ax, ay, az)
    return unless @adapter

    note = @mapper.distance_to_note(dist_mm)
    freq = @mapper.note_to_freq(note)
    fm_depth = @mapper.accel_to_fm_depth(ax, ay, az)
    in_range = @mapper.in_range?(dist_mm)

    @adapter.update_freq(freq.to_f, @glide_sec)
    @adapter.update_fm_depth(fm_depth)
    @adapter.update_gain(in_range ? @volume : 0.0, in_range ? @attack : @release)

    # センサー表示更新
    note_str = @mapper.note_name(note)
    update_sensor_display(dist_mm, ax, ay, az, freq, fm_depth, note_str)
  end

  def on_param(key, value)
    case key
    when "preset"      then switch_preset(value.to_s.to_sym)
    when "scale"       then @mapper.set_scale(value.to_s.to_sym)
    when "oct_up"      then @mapper.transpose_up
    when "oct_down"    then @mapper.transpose_down
    when "glide"       then @glide_sec = value.to_f / 1000.0
    when "glide_time"  then @glide_sec = value.to_f / 1000.0
    when "attack"      then @attack = value.to_f / 1000.0
    when "release"     then @release = value.to_f / 1000.0
    when "dist_curve"  then @mapper.set_dist_curve(value.to_s.to_sym)
    when "accel_curve" then @mapper.set_accel_curve(value.to_s.to_sym)
    when "dist_min"    then @mapper.set_dist_range(value.to_i, @mapper.dist_max)
    when "dist_max"    then @mapper.set_dist_range(@mapper.dist_min, value.to_i)
    when "midi_min"    then @mapper.set_midi_range(value.to_i, @mapper.midi_max)
    when "midi_max"    then @mapper.set_midi_range(@mapper.midi_min, value.to_i)
    when "accel_scale" then @mapper.accel_scale = value.to_f
    else
      # ノードパラメータ (例: "filter:cutoff", "master:gain")
      parts = key.split(":")
      if parts.length == 2
        @adapter&.update_param(parts[0], parts[1], value)
      end
    end
  end

  private

  # プリセット切替 — フェードアウト後に再構築
  def switch_preset(name)
    return unless @adapter
    @adapter.update_gain(0.0, @release)
    release_ms = (@release * 1000).to_i + 50
    app = self
    JS.global.setTimeout(lambda {
      @presets.switch(name)
      @adapter.update_gain(@volume, @attack)
    }, release_ms)
  end

  def update_display(note_name, freq, dist_mm)
    doc = JS.global[:document]
    el = doc.querySelector("#note-display")
    el[:textContent] = note_name if el
    el = doc.querySelector("#freq-display")
    el[:textContent] = "#{freq}Hz" if el
    el = doc.querySelector("#dist-display")
    el[:textContent] = "#{dist_mm}mm" if el
  end

  # センサーUI更新
  def update_sensor_display(dist, ax, ay, az, freq, fm_depth, note_str)
    doc = JS.global[:document]
    el = doc.querySelector("#vD")
    el[:textContent] = dist if el
    el = doc.querySelector("#vN")
    el[:textContent] = note_str if el
    el = doc.querySelector("#vF")
    el[:textContent] = freq if el
    el = doc.querySelector("#vFM")
    el[:textContent] = "#{(fm_depth.to_f * 100).to_i}%" if el
    el = doc.querySelector("#vAX")
    el[:textContent] = ax if el
    el = doc.querySelector("#vAY")
    el[:textContent] = ay if el
    el = doc.querySelector("#vAZ")
    el[:textContent] = az if el
    # 距離ヒストリー更新 (JS側関数)
    upd = JS.global[:updateSensorDisplay]
    if upd.typeof != "undefined"
      JS.global.updateSensorDisplay(dist, ax, ay, az, freq, fm_depth, note_str)
    end
  end

  # シリアル状態UI更新
  def update_serial_status(msg, err_count)
    upd = JS.global[:updateSerialStatus]
    if upd.typeof != "undefined"
      JS.global.updateSerialStatus(msg, err_count)
    end
  end

  # シリアルモニターUI更新
  def update_serial_monitor(line)
    upd = JS.global[:updateSerialMonitor]
    if upd.typeof != "undefined"
      JS.global.updateSerialMonitor(line)
    end
  end
end

# グローバル初期化
$serial = Serial.new
$mapper = SensorMapper.new
$presets = PresetManager.new
$app = SynthApp.new($serial, $mapper, $presets)
$app.register_callbacks
JS.global[:console].log("[Ruby] SynthApp initialized (awaiting Init Audio)")
