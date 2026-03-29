# web/src/ruby/sensor_mapper_test.rb
# SensorMapper既存機能テスト

group "SensorMapper#initialize"

m = SensorMapper.new
assert_equal 20, m.dist_min, "default dist_min"
assert_equal 900, m.dist_max, "default dist_max"
assert_equal 36, m.midi_min, "default midi_min"
assert_equal 84, m.midi_max, "default midi_max"
assert_equal 500.0, m.accel_scale, "default accel_scale"

group "SensorMapper#note_to_freq"

m = SensorMapper.new
assert_equal 440, m.note_to_freq(69), "A4 = 440Hz (integer)"
assert_equal 261, m.note_to_freq(60), "C4 = 261Hz (truncated)"
assert_equal 880, m.note_to_freq(81), "A5 = 880Hz"

group "SensorMapper#note_name"

m = SensorMapper.new
assert_equal "A4", m.note_name(69), "MIDI 69 = A4"
assert_equal "C4", m.note_name(60), "MIDI 60 = C4"
assert_equal "C2", m.note_name(36), "MIDI 36 = C2"
assert_equal "A#4", m.note_name(70), "MIDI 70 = A#4 (sharp notation)"
assert_equal "D#4", m.note_name(63), "MIDI 63 = D#4 (sharp notation)"

group "SensorMapper#distance_to_note — chromatic"

m = SensorMapper.new
m.set_scale(:chromatic)
note_min = m.distance_to_note(20)
note_max = m.distance_to_note(900)
assert_equal 36, note_min, "dist_min → midi_min"
assert_equal 84, note_max, "dist_max → midi_max"

group "SensorMapper#distance_to_note — clamping"

m = SensorMapper.new
m.set_scale(:chromatic)
note_below = m.distance_to_note(0)
note_above = m.distance_to_note(2000)
assert_equal 36, note_below, "below dist_min → midi_min"
assert_equal 84, note_above, "above dist_max → midi_max"

group "SensorMapper#distance_to_note — pentatonic snap"

m = SensorMapper.new
m.set_scale(:pentatonic)
note = m.distance_to_note(460)
scale_degrees = [0, 2, 4, 7, 9]
assert(scale_degrees.include?(note % 12), "pentatonic snap: #{note} mod 12 = #{note % 12}")

group "SensorMapper#accel_to_fm_depth"

m = SensorMapper.new
depth_zero = m.accel_to_fm_depth(0, 0, 0)
assert_equal 0.0, depth_zero, "zero accel → 0.0"

depth_full = m.accel_to_fm_depth(200, 200, 200)
assert(depth_full > 0.0, "nonzero accel → positive depth")
assert(depth_full <= 1.0, "depth clamped to 1.0")

depth_over = m.accel_to_fm_depth(500, 500, 500)
assert_equal 1.0, depth_over, "overflow clamped to 1.0"

group "SensorMapper#in_range?"

m = SensorMapper.new
assert(m.in_range?(100), "100mm in range")
assert(m.in_range?(20), "20mm boundary inclusive")
assert(m.in_range?(900), "900mm boundary inclusive")
assert(!m.in_range?(19), "19mm out of range")
assert(!m.in_range?(901), "901mm out of range")

group "SensorMapper#set_scale"

m = SensorMapper.new
m.set_scale(:major)
m.set_scale(:minor)
m.set_scale(:pentatonic)
m.set_scale(:chromatic)
assert(true, "all scales accepted")

group "SensorMapper#set_dist_range"

m = SensorMapper.new
m.set_dist_range(50, 500)
assert_equal 50, m.dist_min, "dist_min updated"
assert_equal 500, m.dist_max, "dist_max updated"

group "SensorMapper#set_midi_range"

m = SensorMapper.new
m.set_midi_range(48, 72)
assert_equal 48, m.midi_min, "midi_min updated"
assert_equal 72, m.midi_max, "midi_max updated"
