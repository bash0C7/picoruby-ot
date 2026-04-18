# SynthPatch::OscNode: Basic oscillator node (sine/square/sawtooth/triangle).
class SynthPatch
  class OscNode < Node
    attr_reader :waveform, :freq, :amp

    def initialize(waveform, freq:, amp: 1.0, name: nil)
      super(name: name)
      @waveform = waveform
      @freq = freq
      @amp = amp
    end

    def to_spec_h
      {
        id: @name.to_s,
        type: 'oscillator',
        params: {
          waveform: @waveform.to_s,
          frequency: @freq,
          amplitude: @amp
        }
      }
    end

    def to_h
      super.merge(waveform: @waveform, freq: @freq, amp: @amp)
    end

    def status_line
      "#{@name}(osc/#{@waveform}/#{@freq}Hz)"
    end
  end
end
