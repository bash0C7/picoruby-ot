# web/src/ruby/ui_controller.rb
# グラフUI描画＋状態管理
require "js"

class UIController
  def initialize
    @doc = JS.global[:document] rescue nil
    @raf_callback = nil
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

  # アニメーションループ開始
  def start_animation(analyser)
    @analyser = analyser
    # RAFコールバック事前確保 — 毎フレーム新規lambda生成回避
    @raf_callback = lambda { animate_frame }
    animate_frame
  end

  private

  def set_text(selector, text)
    el = @doc.querySelector(selector)
    el[:textContent] = text if el
  end

  def animate_frame
    return unless @analyser
    # JSヘルパー呼び出し — ruby.wasm JS::Object生成を2回/フレームに削減
    JS.global._drawOscilloscope
    JS.global._drawLevelMeter
    JS.global.setTimeout(@raf_callback, 100)
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
