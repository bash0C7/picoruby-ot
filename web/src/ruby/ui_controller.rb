# web/src/ruby/ui_controller.rb
# グラフUI描画＋状態管理
require "js"

class UIController
  def initialize
    @doc = JS.global[:document] rescue nil
  end

  # カーブ描画用データ生成（0.0〜1.0のy値配列）
  def curve_points(curve_type, count)
    return [] if count < 2
    count.times.map do |i|
      ratio = i.to_f / (count - 1)
      apply_curve(ratio, curve_type)
    end
  end

  # オクターブインジケーターindex（0-4、中央が2）
  def octave_index(transpose)
    (transpose / 12) + 2
  end

  # カーブCanvas描画
  def draw_curve(canvas_id, curve_type)
    return unless @doc
    canvas = @doc.querySelector(canvas_id)
    return unless canvas
    ctx = canvas.getContext("2d")
    w = canvas[:width].to_i
    h = canvas[:height].to_i
    points = curve_points(curve_type, w)

    ctx.clearRect(0, 0, w, h)

    # グリッド線
    ctx[:strokeStyle] = "#333"
    ctx[:lineWidth] = 1
    ctx.beginPath
    ctx.moveTo(0, h / 2)
    ctx.lineTo(w, h / 2)
    ctx.stroke

    # カーブ描画
    ctx[:strokeStyle] = "#4caf50"
    ctx[:lineWidth] = 2
    ctx.beginPath
    points.each_with_index do |y, x|
      py = h - (y * h)
      x == 0 ? ctx.moveTo(x, py) : ctx.lineTo(x, py)
    end
    ctx.stroke
  end

  # ステータス表示更新
  def update_status(note_name, freq, dist_mm)
    return unless @doc
    set_text("#note-display", note_name)
    set_text("#freq-display", "#{freq}Hz")
    set_text("#dist-display", "#{dist_mm}mm")
  end

  # オシロスコープ描画
  def draw_oscilloscope(analyser)
    return unless @doc && analyser
    canvas = @doc.querySelector("#oscilloscope")
    return unless canvas
    ctx = canvas.getContext("2d")
    w = canvas[:width].to_i
    h = canvas[:height].to_i

    buf_len = analyser[:frequencyBinCount].to_i
    data = JS.global[:Uint8Array].new(buf_len)
    analyser.getByteTimeDomainData(data)

    ctx.clearRect(0, 0, w, h)
    ctx[:strokeStyle] = "#4caf50"
    ctx[:lineWidth] = 1
    ctx.beginPath

    slice_w = w.to_f / buf_len
    buf_len.times do |i|
      v = data[i].to_f / 128.0
      y = v * h / 2.0
      i == 0 ? ctx.moveTo(0, y) : ctx.lineTo(i * slice_w, y)
    end
    ctx.stroke
  end

  # レベルメーター描画
  def draw_level_meter(analyser)
    return unless @doc && analyser
    canvas = @doc.querySelector("#level-meter")
    return unless canvas
    ctx = canvas.getContext("2d")
    w = canvas[:width].to_i
    h = canvas[:height].to_i

    buf_len = analyser[:frequencyBinCount].to_i
    data = JS.global[:Uint8Array].new(buf_len)
    analyser.getByteTimeDomainData(data)

    sum = 0.0
    buf_len.times { |i| v = (data[i].to_f - 128) / 128.0; sum += v * v }
    rms = Math.sqrt(sum / buf_len)
    level = (rms * 2).clamp(0.0, 1.0)

    ctx.clearRect(0, 0, w, h)
    bar_w = (level * w).to_i
    ctx[:fillStyle] = level > 0.8 ? "#f44336" : "#4caf50"
    ctx.fillRect(0, 0, bar_w, h)
  end

  # アニメーションループ
  def start_animation(analyser)
    @analyser = analyser
    animate_frame
  end

  private

  def set_text(selector, text)
    el = @doc.querySelector(selector)
    el[:textContent] = text if el
  end

  def animate_frame
    return unless @analyser
    draw_oscilloscope(@analyser)
    draw_level_meter(@analyser)
    JS.global.requestAnimationFrame(lambda { |_| animate_frame })
  end

  def apply_curve(ratio, curve_type)
    case curve_type
    when :linear  then ratio
    when :log     then Math.log(1 + ratio * 9) / Math.log(10)
    when :exp     then (10 ** ratio - 1) / 9.0
    when :s_curve then ratio * ratio * (3 - 2 * ratio)
    else ratio
    end
  end
end
