class SensorMapper
  DIST_MIN_DEFAULT = 20
  DIST_MAX_DEFAULT = 900
  FREQ_MIN_DEFAULT = 40
  FREQ_MAX_DEFAULT = 2000

  attr_accessor :accel_scale, :detune_range
  attr_reader :dist_min, :dist_max, :freq_min, :freq_max

  def initialize
    @accel_scale = 500.0
    @detune_range = 20.0
    set_ranges(DIST_MIN_DEFAULT, DIST_MAX_DEFAULT, FREQ_MIN_DEFAULT, FREQ_MAX_DEFAULT)
  end

  def set_ranges(dist_min, dist_max, freq_min, freq_max)
    @dist_min = dist_min.to_i
    @dist_max = dist_max.to_i
    @freq_min = freq_min.to_i
    @freq_max = freq_max.to_i
    @freq_ratio = @freq_max.to_f / @freq_min
  end

  # 距離 → 基本周波数 (対数スケール)
  def distance_to_freq(dist_mm)
    clamped = [[dist_mm, @dist_min].max, @dist_max].min
    ratio = (clamped - @dist_min).to_f / (@dist_max - @dist_min)
    (@freq_min * (@freq_ratio ** ratio)).to_i
  end

  # 加速度magnitude → FMモジュレーション深度 (0.0-1.0)
  def accel_to_fm_depth(ax, ay, az)
    mag = ax.abs + ay.abs + az.abs
    depth = mag.to_f / @accel_scale
    depth > 1.0 ? 1.0 : depth
  end

  def in_range?(dist_mm)
    dist_mm >= @dist_min && dist_mm <= @dist_max
  end
end
