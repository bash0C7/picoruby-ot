# SynthPatch DSL existing feature tests

group "SynthPatch::Node — id generation"

SynthPatch::Node.reset_id_counter!
n1 = SynthPatch::Node.new
n2 = SynthPatch::Node.new
assert(n1.name != n2.name, "unique names")

group "SynthPatch::FMOpNode"

node = SynthPatch::FMOpNode.new(:triangle, freq: 220, amp: 150, name: :test_mod)
assert_equal :triangle, node.waveform, "waveform"
assert_equal 220, node.freq, "freq"
assert_equal 150, node.amp, "amp"
assert_equal :test_mod, node.name, "name"

spec = node.to_spec_h
assert_equal "fm_op", spec[:type], "spec type"

group "SynthPatch::FilterNode"

node = SynthPatch::FilterNode.new(:lowpass, cutoff: 1200, q: 1.5, name: :test_filter)
assert_equal :lowpass, node.filter_type, "filter_type"
assert_equal 1200, node.cutoff, "cutoff"
assert_equal 1.5, node.q, "q"

group "SynthPatch::GainNode"

node = SynthPatch::GainNode.new(0.4, name: :test_gain)
assert_equal 0.4, node.gain_value, "gain_value"

group "SynthPatch::MixerNode"

input1 = SynthPatch::FMOpNode.new(:sine, freq: 440, name: :i1)
input2 = SynthPatch::FMOpNode.new(:sine, freq: 440, name: :i2)
mixer = SynthPatch::MixerNode.new(input1, input2, name: :mix)
assert_equal 2, mixer.inputs.length, "2 inputs"

group "Node#fm connection"

mod = SynthPatch::FMOpNode.new(:triangle, freq: 220, amp: 150, name: :mod)
carrier = SynthPatch::FMOpNode.new(:triangle, freq: 220, name: :carrier)
carrier.fm(mod)
assert_equal mod, carrier.fm_modulator, "fm modulator set"

group "Node#filter chaining"

node = SynthPatch::FMOpNode.new(:sine, freq: 440, name: :src)
filtered = node.filter(:lowpass, cutoff: 1000, q: 1.0, name: :flt)
assert(filtered.is_a?(SynthPatch::FilterNode), "returns FilterNode")

group "Node#gain chaining"

node = SynthPatch::FMOpNode.new(:sine, freq: 440, name: :src2)
gained = node.gain(0.5, name: :gn)
assert(gained.is_a?(SynthPatch::GainNode), "returns GainNode")

group "SynthPatch ADSR defaults"

defaults = SynthPatch::ADSR_DEFAULTS
assert_equal 0.01, defaults[:attack], "default attack"
assert_equal 0.3, defaults[:release], "default release"
assert_equal nil, defaults[:decay], "no decay"
assert_equal nil, defaults[:sustain], "no sustain"

group "SynthPatch — attack/release setters"

patch = SynthPatch.new(nil)
patch.set_attack(0.05)
patch.set_release(0.2)
assert_equal 0.05, patch.attack, "attack set"
assert_equal 0.2, patch.release, "release set"

group "SynthPatch::FxNode — defaults"

node = SynthPatch::FxNode.new(:none, name: :fx)
assert_equal :none, node.fx_type, "fx_type"
assert_in_delta(0.5, node.mix, 0.001, "mix default")
assert_in_delta(0.2, node.delay_time, 0.001, "delay_time default")
assert_in_delta(0.4, node.feedback, 0.001, "feedback default")
assert_in_delta(2.0, node.decay, 0.001, "decay default")
assert_equal 50, node.drive, "drive default"
assert_equal 3000, node.tone, "tone default"

group "SynthPatch::FxNode — to_spec_h"

node = SynthPatch::FxNode.new(:echo, mix: 0.7, delay_time: 0.3, name: :fx)
spec = node.to_spec_h
assert_equal "fx", spec[:type], "spec type"
assert_equal "fx", spec[:id], "spec id"
assert_equal "echo", spec[:params][:fx_type], "params fx_type"
assert_in_delta(0.7, spec[:params][:mix], 0.001, "params mix")
assert_in_delta(0.3, spec[:params][:delay_time], 0.001, "params delay_time")

group "SynthPatch::FxNode — status_line"

node = SynthPatch::FxNode.new(:reverb, mix: 0.5, name: :fx)
assert(node.status_line.include?("reverb"), "status includes type")
