# web/src/ruby/ui_controller_test.rb
# UIController状態管理テスト

group "UIController#curve_points — linear"

uc = UIController.new
points = uc.curve_points(:linear, 5)
assert_equal 5, points.length, "5 points"
assert_in_delta(0.0, points[0], 0.01, "linear first = 0")
assert_in_delta(0.25, points[1], 0.01, "linear second = 0.25")
assert_in_delta(0.5, points[2], 0.01, "linear mid = 0.5")
assert_in_delta(1.0, points[4], 0.01, "linear last = 1")

group "UIController#curve_points — log"

uc = UIController.new
log_points = uc.curve_points(:log, 5)
lin_points = uc.curve_points(:linear, 5)
assert(log_points[2] > lin_points[2], "log midpoint > linear midpoint")

group "UIController#curve_points — edge cases"

uc = UIController.new
assert_equal [], uc.curve_points(:linear, 0), "0 count = empty"
assert_equal [], uc.curve_points(:linear, 1), "1 count = empty"
points2 = uc.curve_points(:linear, 2)
assert_equal 2, points2.length, "2 count = 2 points"

group "UIController#octave_index"

uc = UIController.new
assert_equal 2, uc.octave_index(0), "transpose 0 → index 2 (center)"
assert_equal 3, uc.octave_index(12), "transpose +12 → index 3"
assert_equal 4, uc.octave_index(24), "transpose +24 → index 4"
assert_equal 1, uc.octave_index(-12), "transpose -12 → index 1"
assert_equal 0, uc.octave_index(-24), "transpose -24 → index 0"
