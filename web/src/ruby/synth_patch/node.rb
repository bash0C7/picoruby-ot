# SynthPatch::Node: Base class for all synthesis graph nodes.
# Nodes form a directed graph via chains and FM modulation connections.
class SynthPatch
  class Node
    @@node_id_counter = 0

    def self.next_id
      @@node_id_counter += 1
      :"_n#{@@node_id_counter}"
    end

    def self.reset_id_counter!
      @@node_id_counter = 0
    end

    attr_reader :name, :handle, :chain, :fm_modulator

    def initialize(name: nil)
      @name = name || Node.next_id
      @handle = nil
      @chain = []
      @fm_modulator = nil
      @is_output = false
      @adapter = nil
    end

    def fm(mod_node)
      @fm_modulator = mod_node
      self
    end

    def filter(type, cutoff:, q: 1.0, name: nil)
      node = FilterNode.new(type, cutoff: cutoff, q: q, name: name)
      @chain << node
      node
    end

    def gain(value, name: nil)
      node = GainNode.new(value, name: name)
      @chain << node
      node
    end

    def out
      @is_output = true
      self
    end

    def output?
      @is_output
    end

    def compiled?
      !@handle.nil?
    end

    def set_compiled!(handle, adapter)
      @handle = handle
      @adapter = adapter
    end

    def set_param(param, value)
      raise 'Node not compiled yet. Call SynthPatch.build first.' unless compiled?

      @adapter.update_param(@name, param, value)
    end

    def to_spec_h
      { id: @name.to_s, type: 'node', params: {} }
    end

    def to_h
      {
        name: @name,
        type: self.class.name.split('::').last,
        chain: @chain.map(&:to_h),
        fm_modulator: @fm_modulator&.name
      }
    end

    def status_line
      "#{@name}(#{self.class.name.split('::').last})"
    end
  end
end
