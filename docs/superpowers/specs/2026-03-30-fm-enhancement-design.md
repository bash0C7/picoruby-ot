# FM Enhancement Design: FM Depth Display, C:M Ratio, Feedback

Date: 2026-03-30

## Summary

Three additions to the existing 2-op FM drone synth:

1. **FM depth display** — show current FM depth value in sensor display area
2. **C:M ratio slider** — control carrier:modulator frequency ratio independently
3. **Feedback slider** — self-modulation loop on the modulator operator

## Scope

All changes are in `web/` only. No PicoRuby (`.rb` in `storage/home/`) changes needed.

## 1. FM Depth Display

**Location:** existing sensor display row (alongside D/AX/AY/AZ values)

**Format:** `FM:0.47` (2 decimal places)

**Changes:**
- `ui_controller.rb`: add `fm_depth` argument to `update_sensor_display`, cache `@el_fm_depth` DOM element, update text each frame
- `main.rb`: pass `fm_depth` (already computed) to `update_sensor_display`
- `index.html`: add `<span id="fm-depth-display">` element in sensor row

## 2. C:M Ratio Slider

**UI:** slider range 0.1–8.0, default 1.0, step 0.01. Same style as existing Glide/Attack sliders.

**Behavior:** modulator frequency = carrier frequency × C:M ratio. Applied every frame. Preset switches do not reset the ratio (user setting is preserved).

**Data flow:**
```
slider → rubyOnParamUpdate('cm_ratio', value)
       → SynthApp#on_param → @cm_ratio = value.to_f
       → update() → mod_freq = freq * @cm_ratio
       → batch_update(carrier_freq, mod_freq, fm_depth, glide)
```

**`_audioParamBatchUpdate` signature change:**
```js
// Before: (freq, fmDepthScaled, glide)
// After:  (carrierFreq, modFreq, fmDepthScaled, glide)
```
`modFreq` is now passed independently from `carrierFreq`.

**Changes:**
- `index.html`: add C:M slider, update `_audioParamBatchUpdate(carrierFreq, modFreq, fmDepthScaled, glide)`
- `main.rb`: add `@cm_ratio = 1.0`, compute `mod_freq = freq * @cm_ratio`, update `batch_update` call
- `web_adapter.rb`: update `batch_update` method signature

## 3. Feedback Slider

**UI:** slider range 0.0–1.0, default 0.0. Labeled "FB".

**Web Audio graph:**
```
mod_osc → mod_gain ──────────────────────→ carrier_osc.frequency
               │
               └→ _fbGain → _fbDelay(3ms) → mod_osc.frequency
```

- `_fbDelay`: DelayNode, delayTime = 0.003s (minimum to avoid circular dependency crash)
- `_fbGain`: GainNode, gain = 0.0 initially
- Feedback path is always wired when `:fm_mod` node exists. No DSL changes.
- Effective modulation depth depends on preset amp (e.g. otamatone amp=150 → FB=0.5 means ±75Hz self-modulation)

**JS helper:**
```js
window._setFeedbackAmount = function(amount) {
  var now = ctx.currentTime;
  _fbGainParam.cancelAndHoldAtTime(now);
  _fbGainParam.setTargetAtTime(amount, now, 0.01);
};
```

**`_fbGainParam` cached** alongside `_carrierFreqParam`, `_modFreqParam`, `_modGainParam` in `cache_audio_params`. Re-exposed on preset switch.

**Data flow:**
```
slider → rubyOnParamUpdate('feedback', value)
       → SynthApp#on_param → @adapter.set_feedback(value.to_f)
       → WebAdapter#set_feedback → JS._setFeedbackAmount(amount)
```

**Changes:**
- `index.html`: add FB slider, add `_setFeedbackAmount` JS helper, cache `_fbGainParam`
- `web_adapter.rb`: add feedback node creation in `build_graph`, add `set_feedback(amount)` method, cache `_fbGainParam`
- `main.rb`: handle `'feedback'` in `on_param`

## Files Changed

| File | Changes |
|------|---------|
| `web/index.html` | C:M + FB sliders; `_audioParamBatchUpdate` signature; `_setFeedbackAmount`; `_fbGainParam` cache |
| `web/src/ruby/main.rb` | `@cm_ratio`, `@feedback` state; `batch_update` call; `on_param` extensions |
| `web/src/ruby/synth_patch/web_adapter.rb` | `batch_update` signature; feedback node wiring; `set_feedback` method |
| `web/src/ruby/ui_controller.rb` | `update_sensor_display` fm_depth arg; `@el_fm_depth` cache |

## Out of Scope

- Envelope on FM depth (not suited to drone/sensor paradigm)
- Multi-op algorithms (needs 3+ operators first)
- Preset value changes (presets unchanged; C:M and FB are runtime controls)
- PicoRuby side changes
