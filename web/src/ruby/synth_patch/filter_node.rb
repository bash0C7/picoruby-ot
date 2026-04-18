# SynthPatch::FilterNode: Biquad filter node (lowpass/highpass/bandpass).
class SynthPatch
  class FilterNode < Node
    attr_reader :filter_type, :cutoff, :q

    def initialize(filter_type, cutoff:, q: 1.0, name: nil)
      super(name: name)
      @filter_type = filter_type
      @cutoff = cutoff
      @q = q
    end

    def to_spec_h
      {
        id: @name.to_s,
        type: 'filter',
        params: {
          filter_type: @filter_type.to_s,
          cutoff: @cutoff,
          q: @q
        }
      }
    end

    def to_h
      super.merge(filter_type: @filter_type, cutoff: @cutoff, q: @q)
    end

    def status_line
      "#{@name}(filter/#{@filter_type}/#{@cutoff}Hz/q#{@q})"
    end
  end
end
