class SensorMapper
  DIST_MIN_DEFAULT = 20
  DIST_MAX_DEFAULT = 450
  MIDI_MIN_DEFAULT = 48
  MIDI_MAX_DEFAULT = 72

  NOTE_NAMES = ['C','C#','D','Eb','E','F','F#','G','G#','A','Bb','B']

  attr_accessor :accel_scale
  attr_reader :dist_min, :dist_max, :midi_min, :midi_max, :accel_curve, :transpose

  def initialize
    @accel_scale = 500.0
    @dist_min    = DIST_MIN_DEFAULT
    @dist_max    = DIST_MAX_DEFAULT
    @midi_min    = MIDI_MIN_DEFAULT
    @midi_max    = MIDI_MAX_DEFAULT
    @accel_curve = :linear
    @transpose   = 0
  end

  def set_dist_range(min, max)
    @dist_min = min.to_i
    @dist_max = max.to_i
  end

  def set_midi_range(min, max)
    @midi_min = min.to_i
    @midi_max = max.to_i
  end

  def set_accel_curve(type)
    @accel_curve = type
  end

  def transpose_up
    @transpose = (@transpose + 12).clamp(-24, 24)
  end

  def transpose_down
    @transpose = (@transpose - 12).clamp(-24, 24)
  end

  # 連続MIDIノート値 (float, スナップなし)
  def distance_to_midi_float(dist_mm)
    clamped = dist_mm.clamp(@dist_min, @dist_max)
    ratio   = (clamped - @dist_min).to_f / (@dist_max - @dist_min)
    @midi_min + ratio * (@midi_max - @midi_min) + @transpose
  end

  # equal temperament: MIDI 69 = A3 = 440Hz, semitone = 2^(1/12)
  def note_to_freq(midi_note)
    440.0 * (2.0 ** ((midi_note.to_f - 69.0) / 12.0))
  end

  # A3 = 440Hz 表記 (MIDI 69 → "A3")
  def note_name(midi_note)
    "#{NOTE_NAMES[midi_note % 12]}#{midi_note / 12 - 2}"
  end

  def accel_to_fm_depth(ax, ay, az)
    ratio = ((ax.abs + ay.abs + az.abs).to_f / @accel_scale).clamp(0.0, 1.0)
    apply_curve(ratio, @accel_curve)
  end

  def apply_curve(ratio, curve_type)
    case curve_type
    when :linear  then ratio
    when :log     then Math.log(1 + ratio * 9) / Math.log(10)
    when :exp     then (10 ** ratio - 1) / 9.0
    when :s_curve then ratio * ratio * (3 - 2 * ratio)
    else ratio
    end
  end

  def in_range?(dist_mm)
    dist_mm >= @dist_min && dist_mm <= @dist_max
  end
end
