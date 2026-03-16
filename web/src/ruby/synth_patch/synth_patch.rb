require 'json'

# SynthPatch: DSL-based synthesizer patch definition and runtime control.
# Builds a node graph, compiles it to JSON for the audio adapter, and provides
# a UART-compatible note_on/note_off interface.
class SynthPatch
  ADSR_DEFAULTS = { attack: 0.01, decay: 0.3, sustain: 0.6, release: 0.3 }.freeze

  attr_reader :attack, :decay, :sustain, :release

  def self.build(adapter:, &block)
    patch = new(adapter)
    block.call(patch)
    patch.compile
    patch
  end

  def initialize(adapter)
    @adapter = adapter
    @all_nodes = []
    @named_nodes = {}
    @active = false
    @last_note_time = nil
    @attack  = ADSR_DEFAULTS[:attack]
    @decay   = ADSR_DEFAULTS[:decay]
    @sustain = ADSR_DEFAULTS[:sustain]
    @release = ADSR_DEFAULTS[:release]
  end

  # --- DSL methods ---

  def osc(waveform, freq:, amp: 1.0, name: nil)
    node = OscNode.new(waveform, freq: freq, amp: amp, name: name)
    register_top_level_node(node)
    node
  end

  def fm_op(waveform, freq:, amp: 1.0, name: nil)
    node = FMOpNode.new(waveform, freq: freq, amp: amp, name: name)
    register_top_level_node(node)
    node
  end

  def mix(*inputs, name: nil)
    node = MixerNode.new(*inputs, name: name)
    register_top_level_node(node)
    node
  end

  # --- Named node access ---

  def [](name)
    @named_nodes[name]
  end

  # --- UART-compatible interface ---

  def note_on(freq, duty, now_ms: nil)
    f = freq.to_i
    d = duty.to_i

    if f == 0 || d == 0
      note_off
      return
    end

    @last_note_time = now_ms || (Time.now.to_f * 1000)
    @active = true
    @adapter.note_on(f, d, adsr_params)
  end

  def note_off
    return unless @active

    @active = false
    @adapter.note_off
  end

  def check_timeout(current_ms:, threshold_ms: 200)
    return unless @active
    return unless @last_note_time

    note_off if (current_ms - @last_note_time) > threshold_ms
  end

  def active?
    @active
  end

  # --- ADSR setters ---

  def set_attack(val)
    @attack = val.to_f
  end

  def set_decay(val)
    @decay = val.to_f
  end

  def set_sustain(val)
    @sustain = val.to_f
  end

  def set_release(val)
    @release = val.to_f
  end

  # --- Observability ---

  def status
    node_lines = @named_nodes.map { |_name, node| node.status_line }
    adsr_str = "adsr=#{@attack}/#{@decay}/#{@sustain}/#{@release}"
    active_str = "active=#{@active}"
    (node_lines + [adsr_str, active_str]).join(' ')
  end

  def to_h
    all = collect_all_nodes
    {
      nodes: all.map(&:to_h),
      adsr: { attack: @attack, decay: @decay, sustain: @sustain, release: @release },
      active: @active
    }
  end

  # --- Compile ---

  def compile
    all = collect_all_nodes

    spec = {
      nodes: [],
      connections: [],
      fm_connections: [],
      output_node: nil
    }

    all.each do |node|
      spec[:nodes] << node.to_spec_h

      # FM modulation connections
      if node.respond_to?(:fm_modulator) && node.fm_modulator
        spec[:fm_connections] << { mod: node.fm_modulator.name.to_s, carrier: node.name.to_s }
      end

      # Chain connections: node → first chain node (linear chain)
      spec[:connections] << { from: node.name.to_s, to: node.chain.first.name.to_s } unless node.chain.empty?

      # Mixer input connections
      if node.respond_to?(:inputs)
        node.inputs.each do |input|
          spec[:connections] << { from: input.name.to_s, to: node.name.to_s }
        end
      end

      # Output node
      spec[:output_node] = node.name.to_s if node.output?
    end

    @adapter.build_graph(spec.to_json)
    register_named_nodes(all)
  end

  private

  def register_top_level_node(node)
    @all_nodes << node
  end

  def collect_all_nodes
    result = []
    @all_nodes.each { |n| collect_tree(n, result) }
    result
  end

  def collect_tree(node, result)
    result << node
    node.chain.each { |c| collect_tree(c, result) }
  end

  def register_named_nodes(all_nodes)
    all_nodes.each do |node|
      if node.name
        @named_nodes[node.name] = node
        node.set_compiled!("handle_#{node.name}", @adapter)
      end
    end
  end

  def adsr_params
    { attack: @attack, decay: @decay, sustain: @sustain, release: @release }
  end
end
