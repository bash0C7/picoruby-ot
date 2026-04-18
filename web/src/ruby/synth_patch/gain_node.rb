# SynthPatch::GainNode: Gain (volume) control node.
class SynthPatch
  class GainNode < Node
    attr_reader :gain_value

    def initialize(gain_value, name: nil)
      super(name: name)
      @gain_value = gain_value
    end

    def to_spec_h
      {
        id: @name.to_s,
        type: 'gain',
        params: {
          gain: @gain_value
        }
      }
    end

    def to_h
      super.merge(gain: @gain_value)
    end

    def status_line
      "#{@name}(gain/#{@gain_value})"
    end
  end
end
