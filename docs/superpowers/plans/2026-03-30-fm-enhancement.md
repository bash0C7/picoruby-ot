# FM Enhancement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add FM depth display in sensor area, C:M ratio slider, and feedback slider to the portamento drone web synth.

**Architecture:** Three independent additions to the existing 2-op FM WebAdapter. FM depth display is a pure UI change (1 span + DOM cache). C:M ratio changes the `batch_update` call to pass `mod_freq = carrier_freq * cm_ratio` independently. Feedback uses a DelayNode+GainNode self-modulation loop on the modulator oscillator, wired in `build_graph` and controlled via a new JS helper.

**Tech Stack:** ruby.wasm (Web Audio API via JS interop), vanilla JS helpers, Web Audio API (OscillatorNode, GainNode, DelayNode, AudioParam), Chrome only.

---

## File Map

| File | Changes |
|------|---------|
| `web/index.html` | Add FM/C:M/FB display elements; update `_audioParamBatchUpdate` signature; add `_setFeedbackAmount` JS helper; add sliders; add JS event listeners |
| `web/src/ruby/main.rb` | Cache `@el_fm_depth`; add `@cm_ratio`, `@feedback` state; update `update()` and `on_param()` |
| `web/src/ruby/synth_patch/web_adapter.rb` | Update `batch_update` signature; add feedback nodes in `build_graph`; add `set_feedback` method; cache `@fb_gain_param` |

---

## Task 1: FM Depth Display

Show current FM depth value in the header sensor row alongside Note/Hz/mm.

**Files:**
- Modify: `web/index.html` (header `#note-info` div + CSS)
- Modify: `web/src/ruby/main.rb` (cache + display)

- [ ] **Step 1: Add FM depth span to header in `index.html`**

Find the `#note-info` div (around line 372):
```html
<div id="note-info">
  <span>Note: <span id="note-display">--</span></span>
  <span><span id="freq-display">--</span></span>
  <span><span id="dist-display">--</span></span>
</div>
```
Change to:
```html
<div id="note-info">
  <span>Note: <span id="note-display">--</span></span>
  <span><span id="freq-display">--</span></span>
  <span><span id="dist-display">--</span></span>
  <span>FM:<span id="fm-depth-display">0.00</span></span>
</div>
```

- [ ] **Step 2: Add CSS for `#fm-depth-display` in `index.html`**

After the `#dist-display` CSS rule (around line 50):
```css
#fm-depth-display { color: #f9a; font-size: 16px; }
```

- [ ] **Step 3: Cache `@el_fm_depth` and display value in `main.rb`**

In `initialize` (after `@el_serial = nil` line ~20):
```ruby
@el_fm_depth = nil
```

In `init_audio` (after `@el_serial = ...` line ~37):
```ruby
@el_fm_depth = JS.global[:document].querySelector("#fm-depth-display")
```

In `update_sensor_display` (lines 192-197), add FM depth line:
```ruby
def update_sensor_display(dist, ax, ay, az, freq, fm_depth, note_str)
  return unless @el_note
  begin; @el_note[:textContent] = note_str;                              rescue JS::Error; end
  begin; @el_freq[:textContent] = "#{freq.to_i}Hz";                     rescue JS::Error; end
  begin; @el_dist[:textContent] = "#{dist}mm";                          rescue JS::Error; end
  begin; @el_fm_depth[:textContent] = "%.2f" % fm_depth;                rescue JS::Error; end
end
```

- [ ] **Step 4: Bump `?v=` cache suffix for `main.rb` in `index.html`**

Find (around line 632):
```html
<script type="text/ruby" src="src/ruby/main.rb?v=20260330n"></script>
```
Change to:
```html
<script type="text/ruby" src="src/ruby/main.rb?v=20260330q"></script>
```

- [ ] **Step 5: Verify in browser**

Start server: `cd web && python3 -m http.server 8000`
Open: `http://localhost:8000/index.html`
Click "Init Audio". In Test Mode section, move Dist slider.
Expected: `FM:` value updates alongside Note/Hz/mm in header.

- [ ] **Step 6: Commit**

```bash
git add web/index.html web/src/ruby/main.rb
git commit -m "feat: add FM depth display in sensor header row"
```

---

## Task 2: C:M Ratio Slider

Add a slider (0.1–8.0) that independently controls modulator frequency as `carrier_freq × ratio`. Default 1.0 (current behavior unchanged).

**Files:**
- Modify: `web/index.html` (slider HTML + JS event listener + `_audioParamBatchUpdate` signature)
- Modify: `web/src/ruby/main.rb` (`@cm_ratio` state, `on_param`, `update`)
- Modify: `web/src/ruby/synth_patch/web_adapter.rb` (`batch_update` signature)

- [ ] **Step 1: Add C:M ratio slider HTML in `index.html`**

After the Release slider block (around line 547, after `</div>` of Release):
```html
      <div class="ctrl-row">
        <label>C:M</label>
        <input type="range" id="cm-ratio" min="0.1" max="8.0" step="0.01" value="1.0">
        <span class="cv" id="cm-ratio-val">1.00</span>
      </div>
```

- [ ] **Step 2: Add C:M JS event listener in `index.html`**

Find the Glide/Attack/Release listener block (around line 866):
```js
['glide', 'attack', 'release'].forEach(id => {
```
After that block's closing `});`, add:
```js
var cmEl = document.getElementById('cm-ratio');
if (cmEl) {
  cmEl.addEventListener('input', function() {
    document.getElementById('cm-ratio-val').textContent = parseFloat(cmEl.value).toFixed(2);
    if (window.rubyOnParamUpdate) rubyOnParamUpdate('cm_ratio', cmEl.value);
  });
}
```

- [ ] **Step 3: Update `_audioParamBatchUpdate` in `index.html` to accept `modFreq` independently**

Find (around line 745):
```js
window._audioParamBatchUpdate = function(freq, fmDepthScaled, glide, targetGain, gainTc) {
  var ctx = window._audioCtx;
  if (!ctx) return;
  var now = ctx.currentTime;
  var tc = glide > 0.001 ? glide : 0.001;
  if (window._carrierFreqParam) {
    window._carrierFreqParam.cancelAndHoldAtTime(now);
    window._carrierFreqParam.setTargetAtTime(freq, now, tc);
  }
  if (window._modFreqParam) {
    window._modFreqParam.cancelAndHoldAtTime(now);
    window._modFreqParam.setTargetAtTime(freq, now, tc);
  }
```
Change to:
```js
window._audioParamBatchUpdate = function(carrierFreq, modFreq, fmDepthScaled, glide, targetGain, gainTc) {
  var ctx = window._audioCtx;
  if (!ctx) return;
  var now = ctx.currentTime;
  var tc = glide > 0.001 ? glide : 0.001;
  if (window._carrierFreqParam) {
    window._carrierFreqParam.cancelAndHoldAtTime(now);
    window._carrierFreqParam.setTargetAtTime(carrierFreq, now, tc);
  }
  if (window._modFreqParam) {
    window._modFreqParam.cancelAndHoldAtTime(now);
    window._modFreqParam.setTargetAtTime(modFreq, now, tc);
  }
```

- [ ] **Step 4: Add `@cm_ratio` state and `on_param` handler in `main.rb`**

In `initialize`, after `@mute_dist = nil`:
```ruby
@cm_ratio = 1.0
```

In `on_param`, after `when "accel_scale"` line:
```ruby
when "cm_ratio"    then @cm_ratio = value.to_f
```

- [ ] **Step 5: Update `update()` in `main.rb` to compute and pass `mod_freq`**

Replace lines in `update()`:
```ruby
    @adapter.batch_update(freq, fm_depth, @glide_sec, gain, @release)
```
With:
```ruby
    mod_freq = freq * @cm_ratio
    @adapter.batch_update(freq, mod_freq, fm_depth, @glide_sec, gain, @release)
```

- [ ] **Step 6: Update `WebAdapter#batch_update` signature in `web_adapter.rb`**

Replace:
```ruby
    def batch_update(freq, fm_depth, glide_sec, target_gain, gain_tc)
      return unless @ctx
      JS.global._audioParamBatchUpdate(freq.to_f, (fm_depth.to_f * @fm_depth_scale).to_f, glide_sec.to_f, target_gain.to_f, gain_tc.to_f)
    end
```
With:
```ruby
    def batch_update(carrier_freq, mod_freq, fm_depth, glide_sec, target_gain, gain_tc)
      return unless @ctx
      JS.global._audioParamBatchUpdate(carrier_freq.to_f, mod_freq.to_f, (fm_depth.to_f * @fm_depth_scale).to_f, glide_sec.to_f, target_gain.to_f, gain_tc.to_f)
    end
```

- [ ] **Step 7: Bump `?v=` cache suffixes in `index.html`**

```html
<!-- change these lines -->
<script type="text/ruby" src="src/ruby/synth_patch/web_adapter.rb?v=20260330r"></script>
<script type="text/ruby" src="src/ruby/main.rb?v=20260330s"></script>
```
(use whatever the next sequential suffix letters are after Task 1's commit)

- [ ] **Step 8: Verify in browser**

Open `http://localhost:8000/index.html`, click Init Audio.
Test Mode: move Dist slider, then move C:M slider.
At C:M=1.0: normal sound (same as before).
At C:M=2.0: modulator at 2× carrier freq → brighter/buzzier timbre.
At C:M=0.5: modulator at half carrier freq → darker, sub-harmonic feel.
At C:M=3.7 (non-integer): inharmonic, metallic/bell-like timbre.

- [ ] **Step 9: Commit**

```bash
git add web/index.html web/src/ruby/main.rb web/src/ruby/synth_patch/web_adapter.rb
git commit -m "feat: add C:M ratio slider for independent modulator frequency control"
```

---

## Task 3: Feedback Slider

Add a feedback loop (0.0–1.0) from modulator output back to modulator frequency input via DelayNode (3ms). This causes self-modulation — small amounts add warmth/richness; large amounts create metallic/chaotic timbres.

**Files:**
- Modify: `web/index.html` (slider HTML + JS event listener + `_setFeedbackAmount` helper)
- Modify: `web/src/ruby/synth_patch/web_adapter.rb` (feedback node wiring + `set_feedback` method)
- Modify: `web/src/ruby/main.rb` (`on_param` feedback routing)

- [ ] **Step 1: Add feedback slider HTML in `index.html`**

After the C:M slider block (added in Task 2):
```html
      <div class="ctrl-row">
        <label>FB</label>
        <input type="range" id="feedback" min="0.0" max="1.0" step="0.01" value="0.0">
        <span class="cv" id="feedback-val">0.00</span>
      </div>
```

- [ ] **Step 2: Add FB JS event listener in `index.html`**

After the C:M event listener block added in Task 2:
```js
var fbEl = document.getElementById('feedback');
if (fbEl) {
  fbEl.addEventListener('input', function() {
    document.getElementById('feedback-val').textContent = parseFloat(fbEl.value).toFixed(2);
    if (window.rubyOnParamUpdate) rubyOnParamUpdate('feedback', fbEl.value);
  });
}
```

- [ ] **Step 3: Add `_setFeedbackAmount` JS helper in `index.html`**

After the `_audioParamBatchUpdate` function block (after line 766):
```js
window._setFeedbackAmount = function(amount) {
  var ctx = window._audioCtx;
  if (!ctx || !window._fbGainParam) return;
  var now = ctx.currentTime;
  window._fbGainParam.cancelAndHoldAtTime(now);
  window._fbGainParam.setTargetAtTime(amount, now, 0.01);
};
```

- [ ] **Step 4: Add `@fb_gain_param` to `WebAdapter` initialize and disconnect in `web_adapter.rb`**

In `initialize`, after `@release_gain_param = nil`:
```ruby
@fb_gain_param = nil
```

In `disconnect_all`, after `@master_gain_param = nil`:
```ruby
@fb_gain_param = nil
```
Also expose in JS globals clear: in `disconnect_all` before `@nodes = {}`, the existing loop handles disconnection. No extra step needed — `@nodes[:_fb_gain]` and `@nodes[:_fb_delay]` will be iterated and disconnected.

- [ ] **Step 5: Add `setup_feedback` private method in `web_adapter.rb`**

Add after `connect_nodes` private method:
```ruby
    # フィードバックパス構築 — mod_osc.gain → fb_gain → fb_delay(3ms) → mod_osc.frequency
    def setup_feedback
      mod = @nodes[:fm_mod]
      return unless mod && mod[:gain] && mod[:osc]
      fb_delay = @ctx.createDelay(0.1)
      fb_delay[:delayTime][:value] = 0.003
      fb_gain = @ctx.createGain
      fb_gain[:gain][:value] = 0.0
      mod[:gain].connect(fb_gain)
      fb_gain.connect(fb_delay)
      fb_delay.connect(mod[:osc][:frequency])
      @nodes[:_fb_gain]  = { gain_node: fb_gain }
      @nodes[:_fb_delay] = { delay_node: fb_delay }
    end
```

- [ ] **Step 6: Call `setup_feedback` in `build_graph` in `web_adapter.rb`**

In `build_graph`, after `connect_nodes(spec)`:
```ruby
    def build_graph(json_spec)
      return unless @ctx
      disconnect_all
      spec = JSON.parse(json_spec)
      build_nodes(spec)
      connect_nodes(spec)
      setup_feedback
      cache_audio_params
    end
```

- [ ] **Step 7: Cache `@fb_gain_param` in `cache_audio_params` in `web_adapter.rb`**

In `cache_audio_params`, after `JS.global[:_masterGainParam] = @master_gain_param`:
```ruby
      fb = @nodes[:_fb_gain]
      @fb_gain_param = fb && fb[:gain_node] ? fb[:gain_node][:gain] : nil
      JS.global[:_fbGainParam] = @fb_gain_param
```

- [ ] **Step 8: Add `set_feedback` public method in `web_adapter.rb`**

After `update_gain` method:
```ruby
    def set_feedback(amount)
      return unless @ctx
      JS.global._setFeedbackAmount(amount.to_f)
    end
```

- [ ] **Step 9: Add feedback routing in `on_param` in `main.rb`**

In `on_param`, after `when "cm_ratio"` line:
```ruby
when "feedback"    then @adapter&.set_feedback(value.to_f)
```

- [ ] **Step 10: Bump `?v=` cache suffixes in `index.html`**

```html
<script type="text/ruby" src="src/ruby/synth_patch/web_adapter.rb?v=20260330t"></script>
<script type="text/ruby" src="src/ruby/main.rb?v=20260330u"></script>
```
(use next sequential suffixes)

- [ ] **Step 11: Verify in browser**

Open `http://localhost:8000/index.html`, click Init Audio.
Test Mode: set Dist to ~300mm. Move FB slider slowly from 0.0 upward.
At FB=0.0: no change (same as before).
At FB=0.2–0.4: subtle warmth/richness added.
At FB=0.7+: metallic, chaotic self-oscillation.
Note: `clean` preset has amp=0 so FB has no audible effect (expected behavior — no modulator signal to feed back).
Preset switch: FB path rewires correctly (no crash, continues to function).

- [ ] **Step 12: Commit**

```bash
git add web/index.html web/src/ruby/main.rb web/src/ruby/synth_patch/web_adapter.rb
git commit -m "feat: add feedback slider (DelayNode self-modulation on modulator)"
```
