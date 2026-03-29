# web/src/ruby/serial_test.rb
# Serial既存機能テスト

group "Serial#initialize"

s = Serial.new
assert(!s.connected?, "initially disconnected")
assert_equal 0, s.parse_error_count, "no parse errors initially"
assert_equal 115200, s.baud_rate, "default baud rate"

group "Serial#on_connect"

s = Serial.new
s.on_connect(115200)
assert(s.connected?, "connected after on_connect")
assert_equal 115200, s.baud_rate, "baud rate set"

group "Serial#on_disconnect"

s = Serial.new
s.on_connect(115200)
s.on_disconnect
assert(!s.connected?, "disconnected after on_disconnect")

group "Serial#receive — valid frame"

s = Serial.new
frames = s.receive("<D:0150,AX:0012,AY:-0005,AZ:1002>")
assert_equal 1, frames.length, "one frame parsed"
f = frames[0]
assert_equal 150, f[:distance], "distance"
assert_equal 12, f[:ax], "ax"
assert_equal(-5, f[:ay], "ay negative")
assert_equal 1002, f[:az], "az"

group "Serial#receive — multiple frames in one chunk"

s = Serial.new
frames = s.receive("<D:0100,AX:0001,AY:0002,AZ:0003><D:0200,AX:0004,AY:0005,AZ:0006>")
assert_equal 2, frames.length, "two frames parsed"
assert_equal 100, frames[0][:distance], "first frame distance"
assert_equal 200, frames[1][:distance], "second frame distance"

group "Serial#receive — partial data across calls"

s = Serial.new
frames1 = s.receive("<D:0100,AX")
assert_equal 0, frames1.length, "no complete frame yet"
frames2 = s.receive(":0010,AY:0020,AZ:0030>")
assert_equal 1, frames2.length, "complete frame after second chunk"
assert_equal 100, frames2[0][:distance], "reassembled distance"

group "Serial#receive — malformed frame"

s = Serial.new
frames = s.receive("<D:0100,AX:0010>")
assert_equal 0, frames.length, "malformed frame rejected (only 2 pairs)"
assert_equal 1, s.parse_error_count, "parse error counted"

group "Serial#receive — garbage before frame"

s = Serial.new
frames = s.receive("garbage<D:0150,AX:0012,AY:-0005,AZ:1002>")
assert_equal 1, frames.length, "frame found after garbage"
assert_equal 150, frames[0][:distance], "correct distance"

group "Serial#receive — empty/nil input"

s = Serial.new
frames = s.receive("")
assert_equal 0, frames.length, "empty string → no frames"

group "Serial#rx_log"

s = Serial.new
s.receive("<D:0150,AX:0012,AY:-0005,AZ:1002>\n")
assert(s.rx_log.length > 0, "rx_log has entries")
