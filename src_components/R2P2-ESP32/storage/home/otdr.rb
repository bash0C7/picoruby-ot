# MIDIソフトスルーゲートウェイ！ Power Drums
DEBUG = false

require 'ws2812'
require 'gpio'
require 'irq'
require 'uart'

class MidiGateway
  MIDI_TX_PIN = 22
  MIDI_RX_PIN = 19
  CRASH = 49

  # note→LEDグループ番号マッピング
  GT = {36=>1, 38=>2, 39=>3, 49=>5, 52=>5}

  def initialize(uart)
    @uart = uart
    @midi_buffer = []
    @external_group_history = [4, 4, 4]  # LEDグループ履歴
    @has_crash = false
  end

  def has_crash?
    @has_crash
  end

  def external_group_history
    @external_group_history
  end

  def process_midi
    @has_crash = false

    while @uart.bytes_available > 0
      data = @uart.read(1)
      next unless data && data.length == 1

      byte_val = data[0].ord
      @midi_buffer.push(byte_val)

      # バッファサイズ制限
      if @midi_buffer.length > 12
        @midi_buffer.shift
      end

      # MIDIメッセージ解析（3バイト）
      if @midi_buffer.length >= 3
        status = @midi_buffer[0]

        if status >= 0x80
          case status & 0xF0
          when 0x90  # Note On
            note = @midi_buffer[1]
            velocity = @midi_buffer[2]

            # ソフトスルー
            @uart.write(status.chr + note.chr + velocity.chr)

            if note == CRASH && velocity > 0
              @has_crash = true
            end

            # グループ履歴更新（LEDカラー用）
            if velocity > 0
              g = GT[note] || 4
              if g != 5
                @external_group_history.shift
                @external_group_history.push(g)
              end
            end

          when 0x80  # Note Off
            note = @midi_buffer[1]
            velocity = @midi_buffer[2]
            @uart.write(status.chr + note.chr + velocity.chr)
          end

          @midi_buffer.shift(3)
        else
          # 不正ステータス: 1バイト削除
          @midi_buffer.shift
        end
      end
    end
  end
end

class GatewayLEDVisualizer
  LED_PIN = 33
  LED_COUNT = 60

  # ドラムグループ→色相マップ
  HUES_DRUM = [nil, 0, 128, 192, 64, 0]

  def initialize(led_strip)
    @led_strip = led_strip
    @led_colors = Array.new(LED_COUNT, 0)
    @tick = 0
  end

  def update(group_history)
    @tick += 1
    time_hue_shift = (@tick * 3) % 384

    LED_COUNT.times do |i|
      color_idx = (i + @tick) % group_history.size
      g = group_history[color_idx]
      base_hue = HUES_DRUM[g]
      hue = (base_hue + time_hue_shift + i * 10) % 384
      sb = (200 << 8) | 60
      @led_colors[i] = (hue << 16) | sb
    end
  end

  def show
    @led_strip.show_hsb_hex(*@led_colors)
  end

  def flash
    @led_strip.flash!(LED_COUNT)
  end
end

button = GPIO.new(39, GPIO::IN|GPIO::PULL_UP)
led_strip = WS2812.new(RMTDriver.new(GatewayLEDVisualizer::LED_PIN))

md_uart = UART.new(unit: :ESP32_UART1, baudrate: 31250, txd_pin: MidiGateway::MIDI_TX_PIN, rxd_pin: MidiGateway::MIDI_RX_PIN)
sleep_ms(10)
md_uart.clear_rx_buffer

# Power Drums 初期化（GM2 Program 16 = Power Kit）
md_uart.write((0xB9).chr + (32).chr + (0).chr)
sleep_ms(10)
md_uart.write((0xC9).chr + (16).chr)
sleep_ms(10)

gateway = MidiGateway.new(md_uart)
led_viz = GatewayLEDVisualizer.new(led_strip)

irq = button.irq(GPIO::EDGE_FALL, debounce: 100, capture: {viz: led_viz}) do |btn, ev, cap|
  cap[:viz].flash
end

tick_count = 0

loop do
  IRQ.process
  tick_count += 1

  gateway.process_midi

  if gateway.has_crash?
    led_viz.flash
  end

  if tick_count % 5 == 0
    led_viz.update(gateway.external_group_history)
  end
  if tick_count % 2 == 0
    led_viz.show
  end
end

irq.unregister
