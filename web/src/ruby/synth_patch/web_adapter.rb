require 'js'

# SynthPatch::WebAdapter: Web Audio API direct control via JS.global interop.
# AudioContextノード直接操作
class SynthPatch
  class WebAdapter < AudioAdapter
    attr_reader :analyser

    def initialize
      @ctx = nil
      @nodes = {}
      @analyser = nil
      @fm_depth_scale = 400
      # AudioParamキャッシュ (毎フレームJS::Object生成回避)
      @carrier_freq_param = nil
      @mod_freq_param     = nil
      @mod_gain_param     = nil
      @master_gain_param  = nil
      # リリースボイス (バイオリンレガート用)
      @release_osc        = nil
      @release_gain_node  = nil
      @release_gain_param = nil
      @fb_gain_param = nil
      @fx_type = "none"
      @fx_mix  = 0.5
    end

    def init_audio
      @ctx = JS.global[:AudioContext].new
      @analyser = @ctx.createAnalyser
      @analyser[:fftSize] = 2048
      @analyser.connect(@ctx[:destination])
      # JS描画ループ用にグローバル公開
      JS.global[:analyser] = @analyser
      JS.global[:analyserData] = JS.global[:Float32Array].new(2048)
      # JSヘルパー用にAudioContext公開
      JS.global[:_audioCtx] = @ctx
      init_release_voice
    end

    def audio_context
      @ctx
    end

    def build_graph(json_spec)
      return unless @ctx
      disconnect_all
      spec = JSON.parse(json_spec)
      build_nodes(spec)
      connect_nodes(spec)
      setup_feedback
      cache_audio_params
    end

    # フレーム毎一括更新 (freq + FM depth を1回のJS呼び出しで処理)
    def batch_update(carrier_freq, mod_freq, fm_depth, glide_sec, target_gain, gain_tc)
      return unless @ctx
      JS.global._audioParamBatchUpdate(carrier_freq.to_f, mod_freq.to_f, (fm_depth.to_f * @fm_depth_scale).to_f, glide_sec.to_f, target_gain.to_f, gain_tc.to_f)
    end

    def update_freq(freq, glide_sec)
      return unless @ctx
      now = @ctx[:currentTime].to_f
      tc  = [glide_sec.to_f, 0.001].max
      if @carrier_freq_param
        @carrier_freq_param.cancelAndHoldAtTime(now)
        @carrier_freq_param.setTargetAtTime(freq.to_f, now, tc)
      end
      if @mod_freq_param
        @mod_freq_param.cancelAndHoldAtTime(now)
        @mod_freq_param.setTargetAtTime(freq.to_f, now, tc)
      end
    end

    # リリースボイストリガー (前の音をフェードアウト)
    def trigger_release_voice(old_freq, volume, release_tc)
      return unless @ctx
      JS.global._audioReleaseVoice(old_freq.to_f, (volume.to_f * 0.15).to_f, release_tc.to_f)
    end

    def update_fm_depth(depth)
      return unless @ctx
      return unless @mod_gain_param
      now = @ctx[:currentTime].to_f
      @mod_gain_param.cancelAndHoldAtTime(now)
      @mod_gain_param.setTargetAtTime(depth.to_f * @fm_depth_scale, now, 0.01)
    end

    def update_gain(target, smoothing)
      return unless @ctx
      return unless @master_gain_param
      now = @ctx[:currentTime].to_f
      @master_gain_param.cancelAndHoldAtTime(now)
      @master_gain_param.setTargetAtTime(target.to_f, now, [smoothing.to_f, 0.001].max)
    end

    def set_feedback(amount)
      return unless @ctx
      JS.global._setFeedbackAmount(amount.to_f)
    end

    def update_param(node_name, param, value)
      return unless @ctx
      node = @nodes[node_name.to_sym]
      return unless node
      now = @ctx[:currentTime].to_f
      case param.to_s
      when "waveform"
        node[:osc][:type] = value.to_s if node[:osc]
      when "cutoff"
        node[:filter][:frequency].setTargetAtTime(value.to_f, now, 0.01) if node[:filter]
      when "q"
        node[:filter][:Q].setTargetAtTime(value.to_f, now, 0.01) if node[:filter]
      when "filter_type"
        node[:filter][:type] = value.to_s if node[:filter]
      when "gain"
        g = node[:gain_node]
        g[:gain].setTargetAtTime(value.to_f, now, 0.01) if g
      when "freq"
        node[:osc][:frequency].setTargetAtTime(value.to_f, now, 0.01) if node[:osc]
      when "amp"
        g = node[:gain]
        g[:gain].setTargetAtTime(value.to_f, now, 0.01) if g
      when "fx_type"
        @fx_type = value.to_s
        apply_fx_gains(node, @fx_type, @fx_mix)
      when "mix"
        @fx_mix = value.to_f
        apply_fx_gains(node, @fx_type, @fx_mix)
      when "delay_time"
        node[:delay_node][:delayTime].setTargetAtTime(value.to_f, now, 0.01) if node[:delay_node]
      when "feedback"
        node[:fb_gain][:gain].setTargetAtTime(value.to_f, now, 0.01) if node[:fb_gain]
      when "decay"
        if node[:convolver]
          begin
            ir = JS.global._createReverbIR(value.to_f)
            node[:convolver][:buffer] = ir
          rescue
            nil
          end
        end
      when "drive"
        if node[:waveshaper]
          begin
            curve = JS.global._createDistortionCurve(value.to_f)
            node[:waveshaper][:curve] = curve
          rescue
            nil
          end
        end
      when "tone"
        node[:tone_filter][:frequency].setTargetAtTime(value.to_f, now, 0.01) if node[:tone_filter]
      end
    end

    # note_on/note_off: SynthPatch互換インターフェース
    def note_on(freq, duty, adsr_params)
      update_freq(freq.to_f, 0.005)
      update_gain(0.4, adsr_params[:attack].to_f)
    end

    def note_off
      update_gain(0.0, 0.2)
    end

    private

    # リリースボイス初期化 (sine oscillator + ゲインノード)
    def init_release_voice
      return unless @ctx && @analyser
      @release_osc = @ctx.createOscillator
      @release_osc[:type] = "sine"
      @release_gain_node = @ctx.createGain
      @release_gain_node[:gain][:value] = 0.0
      @release_gain_param = @release_gain_node[:gain]
      @release_osc.connect(@release_gain_node)
      @release_gain_node.connect(@analyser)
      @release_osc.start
      # JSヘルパー用に公開
      JS.global[:_releaseOsc]       = @release_osc
      JS.global[:_releaseGainParam] = @release_gain_param
    end

    # AudioParamキャッシュ更新
    def cache_audio_params
      carrier = @nodes[:fm_carrier]
      mod     = @nodes[:fm_mod]
      master  = @nodes[:master]
      @carrier_freq_param = carrier && carrier[:osc] ? carrier[:osc][:frequency] : nil
      @mod_freq_param     = mod     && mod[:osc]     ? mod[:osc][:frequency]     : nil
      @mod_gain_param     = mod     && mod[:gain]    ? mod[:gain][:gain]         : nil
      @master_gain_param  = master  && master[:gain_node] ? master[:gain_node][:gain] : nil
      fb = @nodes[:_fb_gain]
      @fb_gain_param = fb && fb[:gain_node] ? fb[:gain_node][:gain] : nil
      JS.global[:_fbGainParam] = @fb_gain_param
      # JSヘルパー用に公開 (プリセット切替時も更新)
      JS.global[:_carrierFreqParam] = @carrier_freq_param
      JS.global[:_modFreqParam]     = @mod_freq_param
      JS.global[:_modGainParam]     = @mod_gain_param
      JS.global[:_masterGainParam]  = @master_gain_param
    end

    # 全ノード切断
    def disconnect_all
      # キャッシュクリア
      @carrier_freq_param = nil
      @mod_freq_param     = nil
      @mod_gain_param     = nil
      @master_gain_param  = nil
      @fb_gain_param      = nil
      @fx_type = "none"
      @fx_mix  = 0.5
      @nodes.each_value do |n|
        n.each_value do |web_node|
          next unless web_node.respond_to?(:disconnect)
          begin
            web_node.disconnect
          rescue
            nil
          end
        end
      end
      @nodes = {}
    end

    # ノード生成 (JSON: { "id": ..., "type": ..., "params": {...} })
    def build_nodes(spec)
      (spec["nodes"] || []).each do |node_spec|
        name = node_spec["id"]&.to_sym
        next unless name
        @nodes[name] = create_web_audio_node(node_spec)
      end
    end

    # Web Audioノード種別ごと生成
    def create_web_audio_node(spec)
      params = spec["params"] || {}
      case spec["type"]
      when "fm_op"
        osc = @ctx.createOscillator
        osc[:type] = (params["waveform"] || "sine").to_s
        osc[:frequency][:value] = (params["frequency"] || 220).to_f
        gain = @ctx.createGain
        gain[:gain][:value] = (params["amplitude"] || 1.0).to_f
        osc.connect(gain)
        osc.start
        { osc: osc, gain: gain }
      when "filter"
        filter = @ctx.createBiquadFilter
        filter[:type] = (params["filter_type"] || "lowpass").to_s
        filter[:frequency][:value] = (params["cutoff"] || 1000).to_f
        filter[:Q][:value] = (params["q"] || 1.0).to_f
        { filter: filter }
      when "gain"
        gain = @ctx.createGain
        gain[:gain][:value] = (params["gain"] || 1.0).to_f
        { gain_node: gain }
      when "mixer"
        gain = @ctx.createGain
        gain[:gain][:value] = 1.0
        { gain_node: gain }
      when "fx"
        in_gain = @ctx.createGain
        in_gain[:gain][:value] = 1.0
        out_gain = @ctx.createGain
        out_gain[:gain][:value] = 1.0
        dry_gain = @ctx.createGain
        dry_gain[:gain][:value] = 1.0

        # Echo
        delay_node = @ctx.createDelay(1.0)
        delay_node[:delayTime][:value] = (params["delay_time"] || 0.2).to_f
        fb_gain = @ctx.createGain
        fb_gain[:gain][:value] = (params["feedback"] || 0.4).to_f
        echo_wet = @ctx.createGain
        echo_wet[:gain][:value] = 0.0

        # Reverb
        convolver = @ctx.createConvolver
        decay_val = (params["decay"] || 2.0).to_f
        begin
          ir = JS.global._createReverbIR(decay_val)
          convolver[:buffer] = ir
        rescue
          nil
        end
        reverb_wet = @ctx.createGain
        reverb_wet[:gain][:value] = 0.0

        # Distortion
        waveshaper = @ctx.createWaveShaper
        drive_val = (params["drive"] || 50).to_f
        begin
          curve = JS.global._createDistortionCurve(drive_val)
          waveshaper[:curve] = curve
        rescue
          nil
        end
        waveshaper[:oversample] = "4x"
        tone_filter = @ctx.createBiquadFilter
        tone_filter[:type] = "lowpass"
        tone_filter[:frequency][:value] = (params["tone"] || 3000).to_f
        dist_wet = @ctx.createGain
        dist_wet[:gain][:value] = 0.0

        # Wire: dry path
        in_gain.connect(dry_gain)
        dry_gain.connect(out_gain)
        # Wire: echo path (feedback loop)
        in_gain.connect(delay_node)
        delay_node.connect(fb_gain)
        fb_gain.connect(delay_node)
        delay_node.connect(echo_wet)
        echo_wet.connect(out_gain)
        # Wire: reverb path
        in_gain.connect(convolver)
        convolver.connect(reverb_wet)
        reverb_wet.connect(out_gain)
        # Wire: distortion path
        in_gain.connect(waveshaper)
        waveshaper.connect(tone_filter)
        tone_filter.connect(dist_wet)
        dist_wet.connect(out_gain)

        { in_gain: in_gain, out_gain: out_gain, dry_gain: dry_gain,
          delay_node: delay_node, fb_gain: fb_gain, echo_wet: echo_wet,
          convolver: convolver, reverb_wet: reverb_wet,
          waveshaper: waveshaper, tone_filter: tone_filter, dist_wet: dist_wet }
      else
        {}
      end
    end

    # ノード接続
    def connect_nodes(spec)
      # FM変調接続
      (spec["fm_connections"] || []).each do |fm|
        mod = @nodes[fm["mod"].to_sym]
        carrier = @nodes[fm["carrier"].to_sym]
        next unless mod && carrier
        mod_out = mod[:gain] || mod[:osc]
        carrier_osc = carrier[:osc]
        carrier_freq = carrier_osc ? carrier_osc[:frequency] : nil
        mod_out.connect(carrier_freq) if mod_out && carrier_freq
      end

      # シグナルチェーン接続
      (spec["connections"] || []).each do |conn|
        from_node = @nodes[conn["from"].to_sym]
        to_node = @nodes[conn["to"].to_sym]
        next unless from_node && to_node
        output = get_output(from_node)
        input = get_input(to_node)
        output.connect(input) if output && input
      end

      # output_node → analyser接続
      output_id = spec["output_node"]&.to_sym
      output_node = output_id ? @nodes[output_id] : @nodes[:master]
      if output_node && @analyser
        out = get_output(output_node)
        out.connect(@analyser) if out
      end
    end

    # FXゲイン切替 (全wet=0後、指定タイプのみmixを適用)
    def apply_fx_gains(node, fx_type, mix)
      return unless node
      return unless @ctx
      now = @ctx[:currentTime].to_f
      tc  = 0.01
      mix_f = mix.to_f.clamp(0.0, 1.0)
      dry = fx_type == "none" ? 1.0 : (1.0 - mix_f)
      node[:dry_gain][:gain].setTargetAtTime(dry, now, tc)    if node[:dry_gain]
      node[:echo_wet][:gain].setTargetAtTime(0.0, now, tc)    if node[:echo_wet]
      node[:reverb_wet][:gain].setTargetAtTime(0.0, now, tc)  if node[:reverb_wet]
      node[:dist_wet][:gain].setTargetAtTime(0.0, now, tc)    if node[:dist_wet]
      case fx_type
      when "echo"
        node[:echo_wet][:gain].setTargetAtTime(mix_f, now, tc)   if node[:echo_wet]
      when "reverb"
        node[:reverb_wet][:gain].setTargetAtTime(mix_f, now, tc) if node[:reverb_wet]
      when "distortion"
        node[:dist_wet][:gain].setTargetAtTime(mix_f, now, tc)   if node[:dist_wet]
      end
    end

    # フィードバックパス構築 — mod_osc.gain → fb_gain → fb_delay(3ms) → mod_osc.frequency
    def setup_feedback
      mod = @nodes[:fm_mod]
      return unless mod && mod[:gain] && mod[:osc]
      fb_delay = @ctx.createDelay(0.1)
      fb_delay[:delayTime][:value] = 0.003
      fb_gain = @ctx.createGain
      fb_gain[:gain][:value] = 0.0
      mod[:gain].connect(fb_gain)
      fb_gain.connect(fb_delay)
      fb_delay.connect(mod[:osc][:frequency])
      @nodes[:_fb_gain]  = { gain_node: fb_gain }
      @nodes[:_fb_delay] = { delay_node: fb_delay }
    end

    # 出力端子取得
    def get_output(node)
      node[:out_gain] || node[:gain] || node[:gain_node] || node[:filter] || node[:osc]
    end

    # 入力端子取得
    def get_input(node)
      node[:in_gain] || node[:filter] || node[:gain_node] || node[:osc]
    end
  end
end
