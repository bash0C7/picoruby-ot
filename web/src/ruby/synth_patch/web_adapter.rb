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
    end

    def init_audio
      @ctx = JS.global[:AudioContext].new
      @analyser = @ctx.createAnalyser
      @analyser[:fftSize] = 2048
      @analyser.connect(@ctx[:destination])
      # JS描画ループ用にグローバル公開
      JS.global[:analyser] = @analyser
      JS.global[:analyserData] = JS.global[:Float32Array].new(2048)
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
      cache_audio_params
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

    # AudioParamキャッシュ更新
    def cache_audio_params
      carrier = @nodes[:fm_carrier]
      mod     = @nodes[:fm_mod]
      master  = @nodes[:master]
      @carrier_freq_param = carrier && carrier[:osc] ? carrier[:osc][:frequency] : nil
      @mod_freq_param     = mod     && mod[:osc]     ? mod[:osc][:frequency]     : nil
      @mod_gain_param     = mod     && mod[:gain]    ? mod[:gain][:gain]         : nil
      @master_gain_param  = master  && master[:gain_node] ? master[:gain_node][:gain] : nil
    end

    # 全ノード切断
    def disconnect_all
      # キャッシュクリア
      @carrier_freq_param = nil
      @mod_freq_param     = nil
      @mod_gain_param     = nil
      @master_gain_param  = nil
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

    # 出力端子取得
    def get_output(node)
      node[:gain] || node[:gain_node] || node[:filter] || node[:osc]
    end

    # 入力端子取得
    def get_input(node)
      node[:filter] || node[:gain_node] || node[:osc]
    end
  end
end
