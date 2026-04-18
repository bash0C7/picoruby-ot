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
  MAX_TRIGGERS = 4

  # note→LEDグループ番号マッピング
  GT = {36=>1, 38=>2, 39=>3, 49=>5, 52=>5}

  def initialize(uart)
    @uart = uart
    @midi_buffer = []
    @external_group_history = [4, 4, 4]  # LEDグループ履歴
    @has_crash = false
    @triggered_groups = Array.new(MAX_TRIGGERS, 0)  # 発音グループ記録
    @triggered_count = 0
  end

  def has_crash?
    @has_crash
  end

  def external_group_history
    @external_group_history
  end

  def triggered_count
    @triggered_count
  end

  def triggered_group(i)
    @triggered_groups[i]
  end

  def process_midi
    @has_crash = false
    @triggered_count = 0

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
                # コメットトリガー記録
                if @triggered_count < MAX_TRIGGERS
                  @triggered_groups[@triggered_count] = g
                  @triggered_count += 1
                end
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
  LED_PIN   = 33
  LED_COUNT = 60
  IDLE_BR   = 5     # 無音時の低輝度
  HEAD_BR   = 220   # コメット先頭輝度
  TRAIL_LEN = 20    # トレイル長(LED数)
  SPEED_FP  = 15    # fixed-point /10 = 1.5 LED/update
  MAX_P     = 8

  # ドラムグループ→色相マップ
  HUES_DRUM = [nil, 0, 128, 192, 64, 0]
  IDLE_HUE  = 64

  def initialize(led_strip)
    @led_strip  = led_strip
    @led_colors = Array.new(LED_COUNT, 0)
    @idle_hue   = IDLE_HUE
    @p_pos = Array.new(MAX_P, -1)  # fixed-point *10, -1=inactive
    @p_hue = Array.new(MAX_P, 0)
  end

  def trigger(group)
    MAX_P.times do |i|
      if @p_pos[i] < 0
        @p_pos[i] = 0
        @p_hue[i] = HUES_DRUM[group] || IDLE_HUE
        @idle_hue  = @p_hue[i]
        return
      end
    end
    # 満杯なら末尾スロット上書き
    @p_pos[MAX_P - 1] = 0
    @p_hue[MAX_P - 1] = HUES_DRUM[group] || IDLE_HUE
  end

  def update
    MAX_P.times do |i|
      next if @p_pos[i] < 0
      @p_pos[i] += SPEED_FP
      if @p_pos[i] > (LED_COUNT + TRAIL_LEN) * 10
        @p_pos[i] = -1
      end
    end

    LED_COUNT.times do |i|
      best_br  = IDLE_BR
      best_hue = @idle_hue

      MAX_P.times do |j|
        next if @p_pos[j] < 0
        head = @p_pos[j] / 10
        dist = head - i
        next if dist < 0 || dist > TRAIL_LEN
        # 線形減衰: 先頭=HEAD_BR, TRAIL_LEN離れると0
        br = HEAD_BR * (TRAIL_LEN - dist) / TRAIL_LEN
        if br > best_br
          best_br  = br
          best_hue = @p_hue[j]
        end
      end

      @led_colors[i] = (best_hue << 16) | (200 << 8) | best_br
    end
  end

  def show
    @led_strip.show_hsb_hex(*@led_colors)
  end

  def flash
    @led_strip.flash!(LED_COUNT)
    # @p_pos/@p_hueはここで消さない → flash後にコメット自動復帰
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

  gateway.triggered_count.times do |i|
    led_viz.trigger(gateway.triggered_group(i))
  end

  if tick_count % 2 == 0
    led_viz.update
    led_viz.show
  end
end

irq.unregister
