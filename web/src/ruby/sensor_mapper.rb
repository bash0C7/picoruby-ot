# web/src/ruby/sensor_mapper.rb
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
  attr_reader :dist_min, :dist_max, :midi_min, :midi_max

  def initialize
    @accel_scale = 500.0
    @dist_min    = DIST_MIN_DEFAULT
    @dist_max    = DIST_MAX_DEFAULT
    @midi_min    = MIDI_MIN_DEFAULT
    @midi_max    = MIDI_MAX_DEFAULT
    @scale       = :pentatonic
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

  # Distance → MIDI note (linear scale, scale-snapped)
  def distance_to_note(dist_mm)
    clamped = dist_mm < @dist_min ? @dist_min : (dist_mm > @dist_max ? @dist_max : dist_mm)
    ratio   = (clamped - @dist_min).to_f / (@dist_max - @dist_min)
    span    = @midi_max - @midi_min
    raw     = @midi_min + (ratio * span).to_i
    snap_to_scale(raw)
  end

  # MIDI note → Hz (equal temperament, A4=440Hz)
  def note_to_freq(midi_note)
    (440.0 * (2.0 ** ((midi_note - 69).to_f / 12.0))).to_i
  end

  # MIDI note → display string e.g. "A4"
  def note_name(midi_note)
    name   = NOTE_NAMES[midi_note % 12]
    octave = midi_note / 12 - 1
    "#{name}#{octave}"
  end

  # Accel magnitude → FM depth 0.0-1.0
  def accel_to_fm_depth(ax, ay, az)
    mag   = ax.abs + ay.abs + az.abs
    depth = mag.to_f / @accel_scale
    depth > 1.0 ? 1.0 : depth
  end

  def in_range?(dist_mm)
    dist_mm >= @dist_min && dist_mm <= @dist_max
  end

  private

  def build_scale_notes
    pattern = SCALES[@scale] || SCALES[:pentatonic]
    @scale_notes = []
    (@midi_min..@midi_max).each do |n|
      @scale_notes << n if pattern.include?(n % 12)
    end
    @scale_notes << @midi_min if @scale_notes.empty?
  end

  def snap_to_scale(midi_note)
    best      = @scale_notes[0]
    best_dist = (midi_note - best).abs
    @scale_notes.each do |n|
      d = (midi_note - n).abs
      if d < best_dist
        best_dist = d
        best = n
      end
    end
    best
  end
end
