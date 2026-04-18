# FX Effects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a post-filter FX stage (Off/Echo/Reverb/Distortion) to the Web Synth with per-effect params and Wet/Dry Mix.

**Architecture:** New `FxNode` DSL class mirrors `FilterNode` pattern. `web_adapter.rb` creates all effect Web Audio nodes at build time and switches between them by controlling gain values (no reconnection needed). All preset definitions gain `.fx(:none)` in their chain.

**Tech Stack:** ruby.wasm, Web Audio API (DelayNode, ConvolverNode, WaveShaperNode, BiquadFilterNode, GainNode), JS helpers for IR/curve generation.

---

### Task 1: FxNode DSL class

**Files:**
- Create: `web/src/ruby/synth_patch/fx_node.rb`
- Modify: `web/src/ruby/synth_patch_test.rb`

- [ ] **Step 1: Write failing tests** — append to `web/src/ruby/synth_patch_test.rb`

```ruby
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
```

- [ ] **Step 2: Run tests to verify they fail**

Open `http://localhost:8000/test.html` in browser. Expected: errors about `SynthPatch::FxNode` being undefined.

(Tests won't run in CLI — they run in browser via ruby.wasm. Check browser console for `NameError: uninitialized constant SynthPatch::FxNode`.)

- [ ] **Step 3: Create `web/src/ruby/synth_patch/fx_node.rb`**

```ruby
# SynthPatch::FxNode: FX effects node (off/echo/reverb/distortion).
class SynthPatch
  class FxNode < Node
    attr_reader :fx_type, :mix, :delay_time, :feedback, :decay, :drive, :tone

    def initialize(type, mix: 0.5, delay_time: 0.2, feedback: 0.4,
                   decay: 2.0, drive: 50, tone: 3000, name: nil)
      super(name: name)
      @fx_type   = type
      @mix       = mix
      @delay_time = delay_time
      @feedback  = feedback
      @decay     = decay
      @drive     = drive
      @tone      = tone
    end

    def to_spec_h
      {
        id: @name.to_s,
        type: 'fx',
        params: {
          fx_type:    @fx_type.to_s,
          mix:        @mix,
          delay_time: @delay_time,
          feedback:   @feedback,
          decay:      @decay,
          drive:      @drive,
          tone:       @tone
        }
      }
    end

    def to_h
      super.merge(fx_type: @fx_type, mix: @mix, delay_time: @delay_time,
                  feedback: @feedback, decay: @decay, drive: @drive, tone: @tone)
    end

    def status_line
      "#{@name}(fx/#{@fx_type}/mix#{@mix})"
    end
  end
end
```

- [ ] **Step 4: Commit**

```bash
git add web/src/ruby/synth_patch/fx_node.rb web/src/ruby/synth_patch_test.rb
git commit -m "feat: add FxNode DSL class with echo/reverb/distortion params"
```

---

### Task 2: Node#fx chaining method

**Files:**
- Modify: `web/src/ruby/synth_patch/node.rb` (lines 38–43, after `def gain`)
- Modify: `web/src/ruby/synth_patch_test.rb` (append)

- [ ] **Step 1: Write failing test** — append to `web/src/ruby/synth_patch_test.rb`

```ruby
group "Node#fx chaining"

node = SynthPatch::FMOpNode.new(:sine, freq: 440, name: :src3)
fxed = node.fx(:none, mix: 0.5, name: :fx1)
assert(fxed.is_a?(SynthPatch::FxNode), "returns FxNode")
assert_equal :none, fxed.fx_type, "fx_type none"
assert_equal 1, node.chain.length, "added to chain"

group "Node#fx — signal chain filter.fx.gain"

SynthPatch::Node.reset_id_counter!
flt  = SynthPatch::FilterNode.new(:lowpass, cutoff: 1200, name: :flt2)
fxn  = flt.fx(:echo, name: :fx2)
gn   = fxn.gain(0.4, name: :gn2)
assert(fxn.is_a?(SynthPatch::FxNode), "fx in chain")
assert(gn.is_a?(SynthPatch::GainNode), "gain after fx")
assert_equal 1, flt.chain.length, "filter.chain has fx"
assert_equal 1, fxn.chain.length, "fx.chain has gain"
```

- [ ] **Step 2: Add `fx` method to `web/src/ruby/synth_patch/node.rb`**

Insert after line 43 (after the `def gain` method), before the `def out` method:

```ruby
    def fx(type, mix: 0.5, delay_time: 0.2, feedback: 0.4,
           decay: 2.0, drive: 50, tone: 3000, name: nil)
      node = FxNode.new(type, mix: mix, delay_time: delay_time, feedback: feedback,
                        decay: decay, drive: drive, tone: tone, name: name)
      @chain << node
      node
    end
```

- [ ] **Step 3: Add fx_node.rb script tag to `web/test.html`** — after the mixer_node.rb line:

```html
<script type="text/ruby" src="src/ruby/synth_patch/fx_node.rb?v=20260330h"></script>
```

- [ ] **Step 4: Bump cache busters in `web/test.html`** — change all `?v=20260330g` to `?v=20260330h` for node.rb:

Find: `src="src/ruby/synth_patch/node.rb?v=20260330g"`
Replace: `src="src/ruby/synth_patch/node.rb?v=20260330h"`

- [ ] **Step 5: Verify in browser** — `http://localhost:8000/test.html`

Expected: new FxNode and Node#fx tests PASS, all existing tests still pass.

- [ ] **Step 6: Commit**

```bash
git add web/src/ruby/synth_patch/node.rb web/src/ruby/synth_patch_test.rb web/test.html
git commit -m "feat: add Node#fx chaining method and FxNode to test runner"
```

---

### Task 3: JS helpers for FX audio generation

**Files:**
- Modify: `web/index.html` (JS section, near `_audioParamBatchUpdate`)

- [ ] **Step 1: Add two JS helper functions to `web/index.html`** — in the `<script>` block, after `window._setFeedbackAmount`:

```js
// Reverb IR: white noise × exponential decay envelope
window._createReverbIR = function(decaySeconds) {
  var sampleRate = _audioCtx.sampleRate;
  var length = Math.floor(sampleRate * Math.max(0.1, decaySeconds));
  var buffer = _audioCtx.createBuffer(2, length, sampleRate);
  for (var c = 0; c < 2; c++) {
    var data = buffer.getChannelData(c);
    for (var i = 0; i < length; i++) {
      var t = i / length;
      data[i] = (Math.random() * 2 - 1) * Math.pow(1 - t, 3);
    }
  }
  return buffer;
};

// Distortion: tanh soft-clip curve, drive controls hardness
window._createDistortionCurve = function(drive) {
  var n = 256;
  var curve = new Float32Array(n);
  var d = Math.max(1, drive);
  var norm = Math.tanh(d / 100) + 0.001;
  for (var i = 0; i < n; i++) {
    var x = (i * 2) / n - 1;
    curve[i] = Math.tanh((d / 100) * x) / norm;
  }
  return curve;
};
```

- [ ] **Step 2: Commit**

```bash
git add web/index.html
git commit -m "feat: add _createReverbIR and _createDistortionCurve JS helpers"
```

---

### Task 4: web_adapter.rb — FX node creation

**Files:**
- Modify: `web/src/ruby/synth_patch/web_adapter.rb`

- [ ] **Step 1: Add `@fx_type` and `@fx_mix` to `initialize`** — after `@fb_gain_param = nil`:

```ruby
      @fx_type = "none"
      @fx_mix  = 0.5
```

- [ ] **Step 2: Reset in `disconnect_all`** — after `@fb_gain_param = nil`:

```ruby
      @fx_type = "none"
      @fx_mix  = 0.5
```

- [ ] **Step 3: Add `"fx"` case to `create_web_audio_node`** — append inside the `case spec["type"]` block, before `else`:

```ruby
      when "fx"
        in_gain = @ctx.createGain
        in_gain[:gain][:value] = 1.0
        out_gain = @ctx.createGain
        out_gain[:gain][:value] = 1.0
        dry_gain = @ctx.createGain
        dry_gain[:gain][:value] = 1.0

        # Echo
        delay_node = @ctx.createDelay(1.0)
        delay_node[:delayTime][:value] = (params["delay_time"] || 0.2).to_f
        fb_gain = @ctx.createGain
        fb_gain[:gain][:value] = (params["feedback"] || 0.4).to_f
        echo_wet = @ctx.createGain
        echo_wet[:gain][:value] = 0.0

        # Reverb
        convolver = @ctx.createConvolver
        decay_val = (params["decay"] || 2.0).to_f
        begin
          ir = JS.global._createReverbIR(decay_val)
          convolver[:buffer] = ir
        rescue
          nil
        end
        reverb_wet = @ctx.createGain
        reverb_wet[:gain][:value] = 0.0

        # Distortion
        waveshaper = @ctx.createWaveShaper
        drive_val = (params["drive"] || 50).to_f
        begin
          curve = JS.global._createDistortionCurve(drive_val)
          waveshaper[:curve] = curve
        rescue
          nil
        end
        waveshaper[:oversample] = "4x"
        tone_filter = @ctx.createBiquadFilter
        tone_filter[:type] = "lowpass"
        tone_filter[:frequency][:value] = (params["tone"] || 3000).to_f
        dist_wet = @ctx.createGain
        dist_wet[:gain][:value] = 0.0

        # Wire: dry path
        in_gain.connect(dry_gain)
        dry_gain.connect(out_gain)
        # Wire: echo path (feedback loop)
        in_gain.connect(delay_node)
        delay_node.connect(fb_gain)
        fb_gain.connect(delay_node)
        delay_node.connect(echo_wet)
        echo_wet.connect(out_gain)
        # Wire: reverb path
        in_gain.connect(convolver)
        convolver.connect(reverb_wet)
        reverb_wet.connect(out_gain)
        # Wire: distortion path
        in_gain.connect(waveshaper)
        waveshaper.connect(tone_filter)
        tone_filter.connect(dist_wet)
        dist_wet.connect(out_gain)

        { in_gain: in_gain, out_gain: out_gain, dry_gain: dry_gain,
          delay_node: delay_node, fb_gain: fb_gain, echo_wet: echo_wet,
          convolver: convolver, reverb_wet: reverb_wet,
          waveshaper: waveshaper, tone_filter: tone_filter, dist_wet: dist_wet }
```

- [ ] **Step 4: Update `get_input` and `get_output`** to handle `in_gain`/`out_gain`:

Find:
```ruby
    def get_output(node)
      node[:gain] || node[:gain_node] || node[:filter] || node[:osc]
    end

    def get_input(node)
      node[:filter] || node[:gain_node] || node[:osc]
    end
```

Replace:
```ruby
    def get_output(node)
      node[:out_gain] || node[:gain] || node[:gain_node] || node[:filter] || node[:osc]
    end

    def get_input(node)
      node[:in_gain] || node[:filter] || node[:gain_node] || node[:osc]
    end
```

- [ ] **Step 5: Commit**

```bash
git add web/src/ruby/synth_patch/web_adapter.rb
git commit -m "feat: add FX node creation to web_adapter (echo/reverb/distortion)"
```

---

### Task 5: web_adapter.rb — FX parameter updates

**Files:**
- Modify: `web/src/ruby/synth_patch/web_adapter.rb`

- [ ] **Step 1: Add FX switch helper method** — add private method `apply_fx_gains` before `setup_feedback`:

```ruby
    # FXゲイン切替 (全wet=0後、指定タイプのみmixを適用)
    def apply_fx_gains(node, fx_type, mix)
      return unless node
      now = @ctx[:currentTime].to_f
      tc  = 0.01
      mix_f = mix.to_f.clamp(0.0, 1.0)
      dry = fx_type == "none" ? 1.0 : (1.0 - mix_f)
      node[:dry_gain][:gain].setTargetAtTime(dry, now, tc)    if node[:dry_gain]
      node[:echo_wet][:gain].setTargetAtTime(0.0, now, tc)    if node[:echo_wet]
      node[:reverb_wet][:gain].setTargetAtTime(0.0, now, tc)  if node[:reverb_wet]
      node[:dist_wet][:gain].setTargetAtTime(0.0, now, tc)    if node[:dist_wet]
      case fx_type
      when "echo"
        node[:echo_wet][:gain].setTargetAtTime(mix_f, now, tc)   if node[:echo_wet]
      when "reverb"
        node[:reverb_wet][:gain].setTargetAtTime(mix_f, now, tc) if node[:reverb_wet]
      when "distortion"
        node[:dist_wet][:gain].setTargetAtTime(mix_f, now, tc)   if node[:dist_wet]
      end
    end
```

- [ ] **Step 2: Add FX cases to `update_param`** — in the `case param.to_s` block, before `end`:

```ruby
      when "fx_type"
        @fx_type = value.to_s
        apply_fx_gains(node, @fx_type, @fx_mix)
      when "mix"
        @fx_mix = value.to_f
        apply_fx_gains(node, @fx_type, @fx_mix)
      when "delay_time"
        node[:delay_node][:delayTime].setTargetAtTime(value.to_f, now, 0.01) if node[:delay_node]
      when "feedback"
        node[:fb_gain][:gain].setTargetAtTime(value.to_f, now, 0.01) if node[:fb_gain]
      when "decay"
        if node[:convolver]
          begin
            ir = JS.global._createReverbIR(value.to_f)
            node[:convolver][:buffer] = ir
          rescue
            nil
          end
        end
      when "drive"
        if node[:waveshaper]
          begin
            curve = JS.global._createDistortionCurve(value.to_f)
            node[:waveshaper][:curve] = curve
          rescue
            nil
          end
        end
      when "tone"
        node[:tone_filter][:frequency].setTargetAtTime(value.to_f, now, 0.01) if node[:tone_filter]
```

- [ ] **Step 3: Commit**

```bash
git add web/src/ruby/synth_patch/web_adapter.rb
git commit -m "feat: add FX param update handlers (fx_type, mix, delay_time, feedback, decay, drive, tone)"
```

---

### Task 6: preset_manager.rb — add FX to all presets

**Files:**
- Modify: `web/src/ruby/preset_manager.rb`

- [ ] **Step 1: Add `.fx(:none, name: :fx)` to all 4 presets** — in each preset's `.filter(...).gain(...)` chain, insert `.fx(:none, name: :fx)` between `.filter(...)` and `.gain(...)`:

Each preset currently ends with:
```ruby
           .filter(:lowpass, cutoff: NNNN, q: N.N, name: :filter)
           .gain(0.4, name: :master)
           .out
```

Change to:
```ruby
           .filter(:lowpass, cutoff: NNNN, q: N.N, name: :filter)
           .fx(:none, name: :fx)
           .gain(0.4, name: :master)
           .out
```

Apply to all 4 presets: `:otamatone`, `:clean`, `:acid`, `:retro`.

- [ ] **Step 2: Commit**

```bash
git add web/src/ruby/preset_manager.rb
git commit -m "feat: add default fx(:none) stage to all 4 synth presets"
```

---

### Task 7: main.rb — FX control wiring

**Files:**
- Modify: `web/src/ruby/main.rb`

- [ ] **Step 1: Add `when "fx_type"` to `on_param`** — in the `case key` block, after `when "feedback"`:

```ruby
    when "fx_type"
      type = value.to_s
      @adapter&.update_param("fx", "fx_type", type)
      update_fx_buttons(type)
      update_fx_graph_label(type)
```

- [ ] **Step 2: Add FX entries to `PARAM_ATTRS`** — in the `PARAM_ATTRS` hash, append:

```ruby
    "fx:mix"        => :mix,
    "fx:delay_time" => :delay_time,
    "fx:feedback"   => :feedback,
    "fx:decay"      => :decay,
    "fx:drive"      => :drive,
    "fx:tone"       => :tone
```

- [ ] **Step 3: Update `sync_preset_ui`** — at the end of the method, after the `PARAM_ATTRS.each` block, add:

```ruby
    fx_node = patch[:fx]
    if fx_node
      update_fx_buttons(fx_node.fx_type.to_s)
      update_fx_graph_label(fx_node.fx_type.to_s)
    end
```

- [ ] **Step 4: Add `update_fx_buttons` and `update_fx_graph_label` private methods** — at the end of the `private` section:

```ruby
  # FXタイプボタンのアクティブ状態更新
  def update_fx_buttons(type)
    ["none", "echo", "reverb", "distortion"].each do |t|
      btn = JS.global[:document].querySelector("[data-fx='#{t}']")
      begin
        if t == type
          btn[:classList].add("active")
        else
          btn[:classList].remove("active")
        end
      rescue JS::Error
      end
    end
  end

  # SynthパッチグラフのFXノードラベル更新
  def update_fx_graph_label(type)
    el = JS.global[:document].querySelector("#fx-graph-label")
    begin
      label = type == "none" ? "FX" : "FX(#{type})"
      el[:textContent] = label
    rescue JS::Error
    end
  end
```

- [ ] **Step 5: Commit**

```bash
git add web/src/ruby/main.rb
git commit -m "feat: wire fx_type param to web_adapter, add FX button sync helpers"
```

---

### Task 8: index.html — FX UI and Synth Patch Graph

**Files:**
- Modify: `web/index.html`

- [ ] **Step 1: Add FX node between Filter and Master in patch graph** — find:

```html
      <!-- Arrow: Filter → Master -->
      <div class="node-arrow">→</div>

      <!-- Master node -->
```

Replace with:

```html
      <!-- Arrow: Filter → FX -->
      <div class="node-arrow">→</div>

      <!-- FX node -->
      <div class="node fx">
        <div class="node-title" id="fx-graph-label">FX</div>
        <div class="node-row">
          <div class="btn-group" id="fx-type-group">
            <button data-fx="none" class="active">Off</button>
            <button data-fx="echo">Echo</button>
            <button data-fx="reverb">Reverb</button>
            <button data-fx="distortion">Dist</button>
          </div>
        </div>
        <div class="node-row">
          <label>Mix</label>
          <input type="range" min="0" max="1" step="0.01" value="0.5" data-param="fx:mix">
          <span class="nv">0.50</span>
        </div>
        <div class="node-row fx-params" id="fx-echo-params" style="display:none">
          <label>Dly</label>
          <input type="range" min="0.05" max="1.0" step="0.01" value="0.20" data-param="fx:delay_time">
          <span class="nv">0.20</span>
          <label>FB</label>
          <input type="range" min="0" max="0.95" step="0.01" value="0.40" data-param="fx:feedback">
          <span class="nv">0.40</span>
        </div>
        <div class="node-row fx-params" id="fx-reverb-params" style="display:none">
          <label>Dec</label>
          <input type="range" min="0.5" max="4.0" step="0.1" value="2.0" data-param="fx:decay">
          <span class="nv">2.0</span>
        </div>
        <div class="node-row fx-params" id="fx-dist-params" style="display:none">
          <label>Drv</label>
          <input type="range" min="1" max="100" step="1" value="50" data-param="fx:drive">
          <span class="nv">50</span>
          <label>Tone</label>
          <input type="range" min="500" max="8000" step="100" value="3000" data-param="fx:tone">
          <span class="nv">3000</span>
        </div>
      </div>

      <!-- Arrow: FX → Master -->
      <div class="node-arrow">→</div>

      <!-- Master node -->
```

- [ ] **Step 2: Add JS event listener for FX type buttons** — find the JS listener for `#filter-type-group` and add after it:

```js
// FX type buttons
document.querySelectorAll('#fx-type-group button[data-fx]').forEach(function(btn) {
  btn.addEventListener('click', function() {
    var fxType = this.getAttribute('data-fx');
    document.querySelectorAll('.fx-params').forEach(function(el) { el.style.display = 'none'; });
    if (fxType !== 'none') {
      var paramEl = document.getElementById('fx-' + fxType + '-params');
      if (paramEl) paramEl.style.display = '';
    }
    if (window.rubyOnParamUpdate) window.rubyOnParamUpdate('fx_type', fxType);
  });
});
```

- [ ] **Step 3: Bump cache busters in `web/index.html`** — change version suffix for all changed Ruby files:

- `main.rb?v=...` → bump to new version (e.g. `?v=20260330i`)
- `preset_manager.rb?v=...` → bump
- `synth_patch/node.rb?v=...` → bump
- `synth_patch/web_adapter.rb?v=...` → bump
- Add new: `<script type="text/ruby" src="src/ruby/synth_patch/fx_node.rb?v=20260330i"></script>` after mixer_node.rb tag

To find current versions:
```bash
grep -n "fx_node\|main.rb\|preset_manager\|node.rb\|web_adapter" web/index.html | grep "text/ruby"
```

- [ ] **Step 4: Commit**

```bash
git add web/index.html
git commit -m "feat: add FX node UI to Synth Patch Graph (Off/Echo/Reverb/Distortion)"
```

---

### Task 9: Integration test

**Files:** (no changes)

- [ ] **Step 1: Run web-synth-test skill**

Invoke the `/web-synth-test` skill and verify:
- All existing checks pass (Steps 1–8 from the skill)
- Step 4 (Cockpit UI layout): FX node visible in patch graph with 4 buttons, Mix slider present
- Step 5 (Init Audio): Patch graph shows `FM Mod → FM Carrier → Mixer → Filter → FX → Master → 🔊`
- Step 7 (Test Mode): sensor simulation works with FX off
- New: click Echo button → `#fx-echo-params` visible, `fx_type=echo` sent to Ruby, no console errors
- New: click Reverb button → reverb params row visible, `fx_type=reverb` sent, no console errors
- New: click Dist button → dist params row visible, `fx_type=distortion` sent, no console errors
- New: click Off button → all param rows hidden, dry signal restored, no console errors
- New: Move Mix slider while Echo active → no console errors
- New: Switch preset while Echo active → FX resets to Off, no errors

- [ ] **Step 2: If any test fails** — read console errors, identify which Task introduced the regression, fix in that file, bump cache busters, re-run test.

- [ ] **Step 3: Commit if fixes were needed**

```bash
git add <changed files>
git commit -m "fix: <describe fix>"
```
