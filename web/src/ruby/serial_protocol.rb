module SerialProtocol
  START_MARKER = '<'
  END_MARKER = '>'
  MAX_BUFFER_SIZE = 4096

  def self.decode_sensor(frame)
    return nil unless frame.is_a?(String)
    stripped = frame.strip
    return nil unless stripped.start_with?(START_MARKER) && stripped.end_with?(END_MARKER)

    body = stripped[1..-2]
    pairs = body.split(',')
    return nil unless pairs.length == 4

    values = {}
    pairs.each do |pair|
      parts = pair.split(':')
      return nil unless parts.length == 2
      key, val = parts
      return nil unless val.match?(/\A-?\d+\z/)
      values[key] = val.to_i
    end

    return nil unless values.key?('D') && values.key?('AX') && values.key?('AY') && values.key?('AZ')

    {
      distance: values['D'],
      ax: values['AX'],
      ay: values['AY'],
      az: values['AZ']
    }
  end

  def self.extract_frames(buffer)
    remaining = buffer.dup
    frames = []

    while (start_idx = remaining.index(START_MARKER))
      end_idx = remaining.index(END_MARKER, start_idx)
      break unless end_idx

      frame_str = remaining[start_idx..end_idx]
      decoded = decode_sensor(frame_str)
      frames << decoded if decoded

      remaining = remaining[(end_idx + 1)..]
    end

    if remaining && remaining.index(START_MARKER)
      remaining = remaining[remaining.index(START_MARKER)..]
    else
      remaining = ''
    end

    remaining = remaining[-MAX_BUFFER_SIZE..] if remaining.length > MAX_BUFFER_SIZE

    [frames, remaining]
  end
end
