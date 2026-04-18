# web/src/ruby/serial.rb
class Serial
  MAX_BUFFER = 4096
  LOG_MAX    = 50

  attr_reader :baud_rate, :rx_log, :parse_error_count

  def initialize
    @connected         = false
    @baud_rate         = 115200
    @rx_buffer         = ''
    @rx_log            = []
    @parse_error_count = 0
  end

  def connected?
    @connected
  end

  def on_connect(baud)
    @baud_rate = baud.to_i
    @connected = true
    @rx_buffer = ''
    JS.global[:console].log("[Serial] connected at #{@baud_rate}bps")
  end

  def on_disconnect
    @connected = false
    @rx_buffer = ''
    JS.global[:console].log("[Serial] disconnected")
  end

  def receive(data)
    return [] unless data.is_a?(String) && !data.empty?
    @rx_buffer += data
    frames = []
    while (s = @rx_buffer.index('<'))
      e = @rx_buffer.index('>', s)
      break unless e
      raw = @rx_buffer[s..e]
      frame = decode(raw)
      if frame
        frames << frame
      else
        @parse_error_count += 1
      end
      @rx_buffer = e + 1 < @rx_buffer.length ? @rx_buffer[(e + 1)..] : ''
    end
    keep = @rx_buffer.index('<')
    @rx_buffer = keep ? @rx_buffer[keep..] : ''
    @rx_buffer = @rx_buffer[-MAX_BUFFER..] if @rx_buffer.length > MAX_BUFFER
    last = data.split("\n").last
    if last && !last.strip.empty?
      @rx_log << last.strip
      @rx_log.shift while @rx_log.length > LOG_MAX
    end
    frames
  end

  private

  def decode(raw)
    body = raw[1..-2]
    return nil unless body
    pairs = body.split(',')
    return nil unless pairs.length == 4
    h = {}
    pairs.each do |pair|
      kv = pair.split(':')
      return nil unless kv.length == 2
      k = kv[0]
      v = kv[1]
      return nil unless v && v.match?(/\A-?\d+\z/)
      h[k] = v.to_i
    end
    return nil unless h['D'] && h['AX'] && h['AY'] && h['AZ']
    { distance: h['D'], ax: h['AX'], ay: h['AY'], az: h['AZ'] }
  end
end
