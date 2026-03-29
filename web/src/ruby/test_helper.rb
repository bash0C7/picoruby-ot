# ruby.wasm用ミニテストフレームワーク（Go test方式）
require "js"

$test_count = 0
$fail_count = 0
$current_group = ""

def group(name)
  $current_group = name
  JS.global[:console].log("== #{name} ==")
end

def assert_equal(expected, actual, msg = "")
  $test_count += 1
  label = $current_group.empty? ? msg : "#{$current_group}: #{msg}"
  if expected == actual
    JS.global[:console].log("  PASS: #{label}")
  else
    $fail_count += 1
    JS.global[:console].error("  FAIL: #{label} — expected #{expected.inspect}, got #{actual.inspect}")
  end
end

def assert(val, msg = "")
  assert_equal(true, !!val, msg)
end

def assert_in_delta(expected, actual, delta = 0.001, msg = "")
  $test_count += 1
  label = $current_group.empty? ? msg : "#{$current_group}: #{msg}"
  if (expected - actual).abs <= delta
    JS.global[:console].log("  PASS: #{label}")
  else
    $fail_count += 1
    JS.global[:console].error("  FAIL: #{label} — expected #{expected} ± #{delta}, got #{actual}")
  end
end

def test_summary
  status = $fail_count == 0 ? "ALL PASS" : "#{$fail_count} FAILED"
  msg = "#{$test_count} tests, #{status}"
  JS.global[:console].log(msg)
  el = JS.global[:document].querySelector("#test-result")
  el[:textContent] = msg if el
  el = JS.global[:document].querySelector("#test-detail")
  el[:textContent] = "#{$test_count - $fail_count} passed, #{$fail_count} failed" if el
end
