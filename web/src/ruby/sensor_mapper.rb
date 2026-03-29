class SensorMapper
  DIST_MIN_DEFAULT = 20
  DIST_MAX_DEFAULT = 900
  MIDI_MIN_DEFAULT = 36
  MIDI_MAX_DEFAULT = 84

  NOTE_NAMES = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B']
  SCALES = {
    chromatic:  [0,1,2,3,4,5,6,7,8,9,10,11],
    major:      [0,2,4,5,7,9,11],
    minor:      [0,2,3,5,7,8,10],
    pentatonic: [0,2,4,7,9]
  }

  attr_accessor :accel_scale
  attr_reader :dist_min, :dist_max, :midi_min, :midi_max, :dist_curve, :accel_curve

  def initialize
    @accel_scale = 500.0
    @dist_min    = DIST_MIN_DEFAULT
    @dist_max    = DIST_MAX_DEFAULT
    @midi_min    = MIDI_MIN_DEFAULT
    @midi_max    = MIDI_MAX_DEFAULT
    @scale       = :pentatonic
    @dist_curve  = :linear
    @accel_curve = :linear
    build_scale_notes
  end

  def set_dist_range(min, max)
    @dist_min = min.to_i
    @dist_max = max.to_i
  end

  def set_midi_range(min, max)
    @midi_min = min.to_i
    @midi_max = max.to_i
    build_scale_notes
  end

  def set_scale(name)
    key = name.to_sym
    @scale = SCALES.key?(key) ? key : :pentatonic
    build_scale_notes
  end

  def set_dist_curve(type)
    @dist_curve = type
  end

  def set_accel_curve(type)
    @accel_curve = type
  end

  def distance_to_note(dist_mm)
    clamped = dist_mm.clamp(@dist_min, @dist_max)
    ratio   = (clamped - @dist_min).to_f / (@dist_max - @dist_min)
    curved  = apply_curve(ratio, @dist_curve)
    raw     = @midi_min + (curved * (@midi_max - @midi_min)).round
    snap_to_scale(raw)
  end

  # equal temperament: MIDI 69 = A4 = 440Hz, semitone = 2^(1/12)
  def note_to_freq(midi_note)
    (440.0 * (2.0 ** ((midi_note - 69).to_f / 12.0))).to_i
  end

  def note_name(midi_note)
    "#{NOTE_NAMES[midi_note % 12]}#{midi_note / 12 - 1}"
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

  private

  def build_scale_notes
    pattern = SCALES[@scale] || SCALES[:pentatonic]
    @scale_notes = (@midi_min..@midi_max).select { |n| pattern.include?(n % 12) }
    @scale_notes << @midi_min if @scale_notes.empty?
  end

  def snap_to_scale(midi_note)
    @scale_notes.min_by { |n| (midi_note - n).abs }
  end
end
