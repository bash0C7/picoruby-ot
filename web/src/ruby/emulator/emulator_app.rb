require 'js'

class EmulatorApp
  def initialize
    @connected = false
  end

  def register_callbacks
    app = self
    JS.global[:rubyTick] = lambda do
      app.tick
    end
    JS.global[:rubyEmulatorOnConnect] = lambda do
      app.on_connect
    end
    JS.global[:rubyEmulatorOnDisconnect] = lambda do
      app.on_disconnect
    end
  end

  def on_connect
    @connected = true
  end

  def on_disconnect
    @connected = false
  end

  def tick
    return unless @connected
    d  = JS.global[:emD].to_i
    ax = JS.global[:emAX].to_i
    ay = JS.global[:emAY].to_i
    az = JS.global[:emAZ].to_i
    frame = FrameGenerator.build(d, ax, ay, az)
    JS.global.serialWrite(frame)
    JS.global.updateFrameMonitor(frame.strip)
  end
end
