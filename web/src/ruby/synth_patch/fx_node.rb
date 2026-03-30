# SynthPatch::FxNode: FX effects node (off/echo/reverb/distortion).
class SynthPatch
  class FxNode < Node
    attr_reader :fx_type, :mix, :delay_time, :feedback, :decay, :drive, :tone

    def initialize(type, mix: 0.5, delay_time: 0.2, feedback: 0.4,
                   decay: 2.0, drive: 50, tone: 3000, name: nil)
      super(name: name)
      @fx_type   = type
      @mix       = mix
      @delay_time = delay_time
      @feedback  = feedback
      @decay     = decay
      @drive     = drive
      @tone      = tone
    end

    def to_spec_h
      {
        id: @name.to_s,
        type: 'fx',
        params: {
          fx_type:    @fx_type.to_s,
          mix:        @mix,
          delay_time: @delay_time,
          feedback:   @feedback,
          decay:      @decay,
          drive:      @drive,
          tone:       @tone
        }
      }
    end

    def to_h
      super.merge(fx_type: @fx_type, mix: @mix, delay_time: @delay_time,
                  feedback: @feedback, decay: @decay, drive: @drive, tone: @tone)
    end

    def status_line
      "#{@name}(fx/#{@fx_type}/mix#{@mix})"
    end
  end
end
