# web/src/ruby/sensor_mapper_test.rb
# SensorMapper既存機能テスト

group "SensorMapper#initialize"

m = SensorMapper.new
assert_equal 30, m.dist_min, "default dist_min"
assert_equal 570, m.dist_max, "default dist_max"
assert_equal 48, m.midi_min, "default midi_min"
assert_equal 72, m.midi_max, "default midi_max"
assert_equal 500.0, m.accel_scale, "default accel_scale"

group "SensorMapper#note_to_freq"

m = SensorMapper.new
assert_in_delta(440.0, m.note_to_freq(69), 0.5, "A3 = 440Hz")
assert_in_delta(261.6, m.note_to_freq(60), 1.0, "C3 ~ 261.6Hz")
assert_in_delta(880.0, m.note_to_freq(81), 0.5, "A4 = 880Hz")
assert_in_delta(440.0, m.note_to_freq(69.0), 0.5, "A3 float = 440Hz")

group "SensorMapper#note_name"

m = SensorMapper.new
assert_equal "A3", m.note_name(69), "MIDI 69 = A3"
assert_equal "C3", m.note_name(60), "MIDI 60 = C3"
assert_equal "C1", m.note_name(36), "MIDI 36 = C1"
assert_equal "Bb3", m.note_name(70), "MIDI 70 = Bb3 (mixed notation)"
assert_equal "Eb3", m.note_name(63), "MIDI 63 = Eb3 (mixed notation)"

group "SensorMapper#distance_to_midi_float — chromatic linear"

m = SensorMapper.new
note_min = m.distance_to_midi_float(30)
note_max = m.distance_to_midi_float(570)
assert_in_delta(48.0, note_min, 0.001, "dist_min → midi_min float")
assert_in_delta(72.0, note_max, 0.001, "dist_max → midi_max float")

group "SensorMapper#distance_to_midi_float — clamping"

m = SensorMapper.new
note_below = m.distance_to_midi_float(0)
note_above = m.distance_to_midi_float(2000)
assert_in_delta(48.0, note_below, 0.001, "below dist_min → midi_min float")
assert_in_delta(72.0, note_above, 0.001, "above dist_max → midi_max float")

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
assert(m.in_range?(30), "30mm boundary inclusive")
assert(m.in_range?(570), "570mm boundary inclusive")
assert(!m.in_range?(29), "29mm out of range")
assert(!m.in_range?(571), "571mm out of range")

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

group "SensorMapper#apply_curve — linear"

m = SensorMapper.new
assert_in_delta(0.0, m.apply_curve(0.0, :linear), 0.001, "linear 0.0")
assert_in_delta(0.5, m.apply_curve(0.5, :linear), 0.001, "linear 0.5")
assert_in_delta(1.0, m.apply_curve(1.0, :linear), 0.001, "linear 1.0")

group "SensorMapper#apply_curve — log"

m = SensorMapper.new
assert_in_delta(0.0, m.apply_curve(0.0, :log), 0.001, "log 0.0")
val = m.apply_curve(0.5, :log)
assert(val > 0.5, "log 0.5 > 0.5 (early sensitivity): #{val}")
assert_in_delta(1.0, m.apply_curve(1.0, :log), 0.001, "log 1.0")

group "SensorMapper#apply_curve — exp"

m = SensorMapper.new
assert_in_delta(0.0, m.apply_curve(0.0, :exp), 0.001, "exp 0.0")
val = m.apply_curve(0.5, :exp)
assert(val < 0.5, "exp 0.5 < 0.5 (late sensitivity): #{val}")
assert_in_delta(1.0, m.apply_curve(1.0, :exp), 0.001, "exp 1.0")

group "SensorMapper#apply_curve — s_curve"

m = SensorMapper.new
assert_in_delta(0.0, m.apply_curve(0.0, :s_curve), 0.001, "s_curve 0.0")
assert_in_delta(0.5, m.apply_curve(0.5, :s_curve), 0.001, "s_curve 0.5 = midpoint")
assert_in_delta(1.0, m.apply_curve(1.0, :s_curve), 0.001, "s_curve 1.0")

group "SensorMapper — accel_curve state"

m = SensorMapper.new
assert_equal :linear, m.accel_curve, "default accel_curve is linear"

m.set_accel_curve(:exp)
assert_equal :exp, m.accel_curve, "accel_curve updated to exp"

group "SensorMapper#accel_to_fm_depth — with exp curve"

m = SensorMapper.new
m.set_accel_curve(:exp)
depth_exp = m.accel_to_fm_depth(100, 100, 100)
m2 = SensorMapper.new
depth_lin = m2.accel_to_fm_depth(100, 100, 100)
assert(depth_exp <= depth_lin, "exp curve: depth_exp(#{depth_exp}) <= depth_lin(#{depth_lin})")

group "SensorMapper — transpose"

m = SensorMapper.new
assert_equal 0, m.transpose, "default transpose = 0"

m.transpose_up
assert_equal 12, m.transpose, "transpose_up → +12"

m.transpose_up
assert_equal 24, m.transpose, "transpose_up → +24"

m.transpose_up
assert_equal 24, m.transpose, "clamped at +24"

m.transpose_down
assert_equal 12, m.transpose, "transpose_down → +12"

4.times { m.transpose_down }
assert_equal(-24, m.transpose, "clamped at -24")

group "SensorMapper#distance_to_midi_float — with transpose"

m = SensorMapper.new
base_note = m.distance_to_midi_float(460)
m.transpose_up
transposed_note = m.distance_to_midi_float(460)
assert_in_delta(base_note + 12.0, transposed_note, 0.001, "transpose +12 applied")

group "SensorMapper#note_name — mixed notation"

m = SensorMapper.new
assert_equal "C3", m.note_name(60), "C3"
assert_equal "C#3", m.note_name(61), "C#3"
assert_equal "D3", m.note_name(62), "D3"
assert_equal "Eb3", m.note_name(63), "Eb3"
assert_equal "E3", m.note_name(64), "E3"
assert_equal "F3", m.note_name(65), "F3"
assert_equal "F#3", m.note_name(66), "F#3"
assert_equal "G3", m.note_name(67), "G3"
assert_equal "G#3", m.note_name(68), "G#3"
assert_equal "A3", m.note_name(69), "A3"
assert_equal "Bb3", m.note_name(70), "Bb3"
assert_equal "B3", m.note_name(71), "B3"
assert_equal "C4", m.note_name(72), "C4"
