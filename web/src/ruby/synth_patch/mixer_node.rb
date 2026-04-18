# SynthPatch::MixerNode: Mixes multiple input nodes into a single output.
class SynthPatch
  class MixerNode < Node
    attr_reader :inputs

    def initialize(*inputs, name: nil)
      super(name: name)
      @inputs = inputs
    end

    def to_spec_h
      {
        id: @name.to_s,
        type: 'mixer',
        params: {
          input_count: @inputs.length
        }
      }
    end

    def to_h
      super.merge(inputs: @inputs.map { |n| n.name })
    end

    def status_line
      "#{@name}(mixer/#{@inputs.length}inputs)"
    end
  end
end
