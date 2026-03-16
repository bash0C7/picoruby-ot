class SerialManager
  DEFAULT_BAUD = 115_200
  RX_LOG_MAX_LINES = 100

  attr_reader :baud_rate, :rx_log, :rx_buffer

  def initialize
    @connected = false
    @baud_rate = DEFAULT_BAUD
    @rx_buffer = ''
    @rx_log = []
  end

  def connected?
    @connected
  end

  def on_connect(baud_rate)
    @baud_rate = baud_rate.to_i
    @connected = true
    @rx_buffer = ''
    JSBridge.log("serial connected at #{@baud_rate}bps")
  end

  def on_disconnect
    @connected = false
    @rx_buffer = ''
    JSBridge.log("serial disconnected")
  end

  def receive_data(data)
    return [] unless data.is_a?(String) && !data.empty?

    @rx_buffer += data
    frames, @rx_buffer = SerialProtocol.extract_frames(@rx_buffer)

    data.split("\n").each do |line|
      next if line.strip.empty?
      log_rx(line.strip)
    end

    frames
  end

  def status
    state = @connected ? "connected" : "disconnected"
    "#{state} #{@baud_rate}bps"
  end

  private

  def log_rx(text)
    @rx_log << text
    @rx_log.shift while @rx_log.length > RX_LOG_MAX_LINES
  end
end
