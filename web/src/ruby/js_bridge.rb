require 'js'

module JSBridge
  def self.log(message)
    JS.global[:console].log("[Ruby] #{message}")
  rescue => e
    $stderr.puts "[Ruby][WARN] console.log failed: #{e.message}"
  end

  def self.error(message)
    JS.global[:console].error("[Ruby] #{message}")
  rescue => e
    $stderr.puts "[Ruby][WARN] console.error failed: #{e.message}"
  end

  def self.update_sensor_display(dist, ax, ay, az, freq, fm_depth)
    JS.global.updateSensorDisplay(dist, ax, ay, az, freq, fm_depth)
  rescue => e
    JS.global[:console].error("[Ruby] JSBridge error: #{e.message}")
  end

  def self.update_synth_params(freq, fm_depth, active)
    JS.global.updateSensorParams(freq, fm_depth, active ? 1 : 0)
  rescue => e
    JS.global[:console].error("[Ruby] JSBridge synth error: #{e.message}")
  end
end
