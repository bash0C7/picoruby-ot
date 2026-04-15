require 'js'

class SynthApp
  def initialize(serial, mapper, presets)
    @serial  = serial
    @mapper  = mapper
    @presets = presets
    @adapter = nil
    @ui = UIController.new
    @glide_sec = 0.020
    @attack = 0.01
    @release = 0.3
    @volume = 0.4
    @muted = false
    @stashed_volume = nil
    @mute_dist = nil
    @cm_ratio = 1.0
    @serial_monitor_text = ""
    # DOM要素キャッシュ (毎フレームquerySelector回避)
    @el_note   = nil
    @el_freq   = nil
    @el_dist   = nil
    @el_serial   = nil
    @el_fm_depth = nil
  end

  def init_audio
    @adapter = SynthPatch::WebAdapter.new
    @adapter.init_audio
    @presets.set_adapter(@adapter)
    @presets.switch(:otamatone)
    sync_preset_ui(@presets.patch)
    # オシロスコープ・レベルメーター開始
    @ui.start_animation(@adapter.analyser)
    # アクセルカーブ描画
    @ui.draw_curve("#accel-curve-canvas", :linear)
    # DOM要素キャッシュ初期化
    @el_note   = JS.global[:document].querySelector("#note-display")
    @el_freq   = JS.global[:document].querySelector("#freq-display")
    @el_dist   = JS.global[:document].querySelector("#dist-display")
    @el_serial   = JS.global[:document].querySelector("#serial-monitor")
    @el_fm_depth = JS.global[:document].querySelector("#fm-depth-display")
    JS.global[:console].log("[Ruby] Audio initialized")
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
    @adapter&.update_gain(@volume, @attack)
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
    frame = frames.last  # 最新フレームのみ処理 (latency削減)
    if frame
      begin
        update(frame[:distance], frame[:ax], frame[:ay], frame[:az])
      rescue => e
        JS.global[:console].error("[Ruby update] #{e.class}: #{e.message}")
      end
    end
    begin
      update_serial_monitor(@serial.rx_log.last.to_s)
    rescue => e
      JS.global[:console].error("[Ruby serial_monitor] #{e.class}: #{e.message}")
    end
  rescue => e
    JS.global[:console].error("[Ruby on_receive] #{e.class}: #{e.message}")
  end

  # 更新ループ — ドローン常時オン、常時フレーム補間
  def update(dist_mm, ax, ay, az)
    return unless @adapter

    midi_float = @mapper.distance_to_midi_float(dist_mm)
    freq       = @mapper.note_to_freq(midi_float)
    fm_depth   = @mapper.accel_to_fm_depth(ax, ay, az)

    @mute_dist = @mute_dist ? @mute_dist * 0.7 + dist_mm * 0.3 : dist_mm.to_f
    gain = @mute_dist < 25 ? 0.0 : @volume
    mod_freq = freq * @cm_ratio
    @adapter.batch_update(freq, mod_freq, fm_depth, @glide_sec, gain, @release)

    note_str = @mapper.note_name(midi_float.round)  # 表示のみ: 最近傍ノート名
    update_sensor_display(dist_mm, ax, ay, az, freq, fm_depth, note_str)
  end

  def on_param(key, value)
    case key
    when "preset"      then switch_preset(value.to_s.to_sym)
    when "oct_up"      then @mapper.transpose_up; update_octave_display
    when "oct_down"    then @mapper.transpose_down; update_octave_display
    when "glide"       then @glide_sec = value.to_f / 1000.0
    when "attack"      then @attack = value.to_f / 1000.0
    when "release"     then @release = value.to_f / 1000.0
    when "accel_curve"
      curve = value.to_s.to_sym
      @mapper.set_accel_curve(curve)
      @ui.draw_curve("#accel-curve-canvas", curve)
    when "dist_min"    then @mapper.set_dist_range(value.to_i, @mapper.dist_max)
    when "dist_max"    then @mapper.set_dist_range(@mapper.dist_min, value.to_i)
    when "midi_min"    then @mapper.set_midi_range(value.to_i, @mapper.midi_max)
    when "midi_max"    then @mapper.set_midi_range(@mapper.midi_min, value.to_i)
    when "accel_scale" then @mapper.accel_scale = value.to_f
    when "cm_ratio"    then @cm_ratio = value.to_f
    when "feedback"    then @adapter&.set_feedback(value.to_f)
    when "mute"
      if @muted
        @muted = false
        @volume = @stashed_volume if @stashed_volume
        @adapter&.update_gain(@volume, @attack)
      else
        @stashed_volume = @volume
        @volume = 0.0
        @muted = true
        @adapter&.update_gain(0.0, 0.005)
      end
      update_mute_button(@muted)
    when "fx_type"
      type = value.to_s
      @adapter&.update_param("fx", "fx_type", type)
      update_fx_buttons(type)
      update_fx_graph_label(type)
    else
      # ノードパラメータ (例: "filter:cutoff", "master:gain")
      parts = key.split(":")
      if parts.length == 2
        @adapter&.update_param(parts[0], parts[1], value)
      end
    end
  end

  private

  # data-param属性 → ノード属性名マッピング
  PARAM_ATTRS = {
    "fm_mod:waveform"     => :waveform,
    "fm_mod:freq"         => :freq,
    "fm_mod:amp"          => :amp,
    "fm_carrier:waveform" => :waveform,
    "mixer:gain"          => :gain_value,
    "filter:filter_type"  => :filter_type,
    "filter:cutoff"       => :cutoff,
    "filter:q"            => :q,
    "master:gain"         => :gain_value,
    "fx:mix"        => :mix,
    "fx:delay_time" => :delay_time,
    "fx:feedback"   => :feedback,
    "fx:decay"      => :decay,
    "fx:drive"      => :drive,
    "fx:tone"       => :tone
  }

  # プリセット切替時にUIコントロール値を同期
  def sync_preset_ui(patch)
    return unless patch
    PARAM_ATTRS.each do |param_key, attr|
      node_name = param_key.split(":")[0].to_sym
      node = patch[node_name]
      next unless node
      val = node.respond_to?(attr) ? node.send(attr) : nil
      next unless val
      set_value("[data-param='#{param_key}']", val)
    end
    fx_node = patch[:fx]
    if fx_node
      update_fx_buttons(fx_node.fx_type.to_s)
      update_fx_graph_label(fx_node.fx_type.to_s)
    end
  end

  def set_value(selector, val)
    el = JS.global[:document].querySelector(selector)
    begin
      el[:value] = val.to_s
    rescue JS::Error
    end
  end

  # プリセット切替 — フェードアウト後に再構築
  def switch_preset(name)
    return unless @adapter
    @adapter.update_gain(0.0, @release)
    release_ms = (@release * 1000).to_i + 50
    JS.global.setTimeout(lambda {
      @presets.switch(name)
      sync_preset_ui(@presets.patch)
      @adapter.update_gain(@volume, @attack)
    }, release_ms)
  end

  # オクターブドットインジケーター更新
  def update_octave_display
    idx = @ui.octave_index(@mapper.transpose)
    5.times do |i|
      dot = JS.global[:document].querySelector("#oct-dot-#{i}")
      begin
        if i == idx
          dot[:classList].add("active")
        else
          dot[:classList].remove("active")
        end
      rescue JS::Error
        # element not found
      end
    end
  end

  # センサーUI更新
  def update_sensor_display(dist, ax, ay, az, freq, fm_depth, note_str)
    return unless @el_note
    begin; @el_note[:textContent] = note_str;                              rescue JS::Error; end
    begin; @el_freq[:textContent] = "#{freq.to_i}Hz";                     rescue JS::Error; end
    begin; @el_dist[:textContent] = "#{dist}mm";                          rescue JS::Error; end
    begin; @el_fm_depth[:textContent] = "%.2f" % fm_depth;                rescue JS::Error; end
  end

  # JS null安全なテキスト設定
  def set_text(selector, text)
    el = JS.global[:document].querySelector(selector)
    begin
      el[:textContent] = text.to_s
    rescue JS::Error
      # querySelector returned null
    end
  end

  # シリアル状態UI更新
  def update_serial_status(msg, err_count)
    connected = msg.include?("connected at")
    el = JS.global[:document].querySelector("#serial-status")
    begin
      el[:style][:color] = connected ? "#4caf50" : "#f44336"
    rescue JS::Error
    end
  end

  # シリアルモニターUI更新 — details非表示時はスキップ (CPU節約)
  def update_serial_monitor(line)
    return unless @el_serial
    return if JS.global._serialMonitorOpen.to_s == "false"
    @serial_monitor_text = (line + "\n" + @serial_monitor_text)[0, 2000]
    begin
      @el_serial[:textContent] = @serial_monitor_text
    rescue JS::Error
    end
  end

  # ミュートボタン表示更新
  def update_mute_button(muted)
    btn = JS.global[:document].querySelector("#btn-mute")
    begin
      if muted
        btn[:textContent] = "Unmute"
        btn[:classList].add("active")
      else
        btn[:textContent] = "Mute"
        btn[:classList].remove("active")
      end
    rescue JS::Error
    end
  end

  # FXタイプボタンのアクティブ状態更新
  def update_fx_buttons(type)
    ["none", "echo", "reverb", "distortion"].each do |t|
      btn = JS.global[:document].querySelector("[data-fx='#{t}']")
      begin
        if t == type
          btn[:classList].add("active")
        else
          btn[:classList].remove("active")
        end
      rescue JS::Error
      end
      row = JS.global[:document].querySelector("#fx-#{t}-params")
      begin
        row[:style][:display] = (t == type && t != "none") ? "" : "none"
      rescue JS::Error
      end
    end
  end

  # SynthパッチグラフのFXノードラベル更新
  def update_fx_graph_label(type)
    el = JS.global[:document].querySelector("#fx-graph-label")
    begin
      label = type == "none" ? "FX" : "FX(#{type})"
      el[:textContent] = label
    rescue JS::Error
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
