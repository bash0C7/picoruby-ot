# web/src/ruby/preset_manager.rb
class PresetManager
  PRESETS = [:otamatone, :clean, :acid, :retro].freeze

  attr_reader :current, :patch

  def initialize
    @current = nil
    @patch = nil
    @adapter = nil
  end

  # 外部アダプター注入
  def set_adapter(adapter)
    @adapter = adapter
  end

  def switch(name)
    key = name.to_s.to_sym
    return unless PRESETS.include?(key) && @adapter
    @current = key
    @patch = build(key)
  end

  private

  def build(name)
    case name
    when :otamatone
      SynthPatch.build(adapter: @adapter) do |syn|
        mod     = syn.fm_op(:triangle, freq: 220, amp: 150, name: :fm_mod)
        carrier = syn.fm_op(:triangle, freq: 220, name: :fm_carrier)
        carrier.fm(mod)
        syn.mix(carrier, name: :mixer)
           .filter(:lowpass, cutoff: 1200, q: 1.5, name: :filter)
           .gain(0.4, name: :master)
           .out
      end
    when :clean
      SynthPatch.build(adapter: @adapter) do |syn|
        mod     = syn.fm_op(:sine, freq: 220, amp: 0, name: :fm_mod)
        carrier = syn.fm_op(:sine, freq: 220, name: :fm_carrier)
        carrier.fm(mod)
        syn.mix(carrier, name: :mixer)
           .filter(:lowpass, cutoff: 4000, q: 0.7, name: :filter)
           .gain(0.4, name: :master)
           .out
      end
    when :acid
      SynthPatch.build(adapter: @adapter) do |syn|
        mod     = syn.fm_op(:sine, freq: 220, amp: 300, name: :fm_mod)
        carrier = syn.fm_op(:sawtooth, freq: 220, name: :fm_carrier)
        carrier.fm(mod)
        syn.mix(carrier, name: :mixer)
           .filter(:lowpass, cutoff: 600, q: 8.0, name: :filter)
           .gain(0.4, name: :master)
           .out
      end
    when :retro
      SynthPatch.build(adapter: @adapter) do |syn|
        mod     = syn.fm_op(:square, freq: 220, amp: 80, name: :fm_mod)
        carrier = syn.fm_op(:square, freq: 220, name: :fm_carrier)
        carrier.fm(mod)
        syn.mix(carrier, name: :mixer)
           .filter(:lowpass, cutoff: 2000, q: 1.0, name: :filter)
           .gain(0.4, name: :master)
           .out
      end
    end
  end
end
