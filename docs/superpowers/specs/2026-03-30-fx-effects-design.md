# FX Effects for Web Synth — Design Spec

Date: 2026-03-30

## Overview

Add an FX stage after the Filter node in the Synth Patch Graph. Four exclusive modes: Off, Echo, Reverb, Distortion. Each mode has dedicated parameters plus a shared Wet/Dry Mix knob.

## 1. Signal Chain & DSL

Signal chain: `Filter → FX → Master`

FX node internal structure:
```
[in_gain] ──────────────────────────────► [out_gain]
    │                                          ▲
    └──► [wet path: effect nodes] ──► [wet_gain]
```

When `fx_type = :none`, `wet_gain.gain = 0` (dry signal passes unchanged).

DSL syntax (chainable, same pattern as FilterNode):
```ruby
.fx(:none, mix: 0.5, name: :fx)
```

FxNode attributes:
- `fx_type` — `:none / :echo / :reverb / :distortion`
- `mix` — wet level 0.0–1.0 (default 0.5)
- `delay_time` — echo delay in seconds (default 0.2)
- `feedback` — echo feedback gain (default 0.4)
- `decay` — reverb tail length in seconds (default 2.0)
- `drive` — distortion curve hardness (default 50)
- `tone` — distortion tone filter cutoff Hz (default 3000)

JSON compilation:
```json
{"id": "fx", "type": "fx", "params": {"fx_type": "none", "mix": 0.5, "delay_time": 0.2, "feedback": 0.4, "decay": 2.0, "drive": 50, "tone": 3000}}
```

## 2. Web Audio Implementation

### Echo
```
in_gain → delay_node(delay_time) → fb_gain(feedback) → (back to delay_node input)
                                 → wet_gain
```
Nodes: `DelayNode` + feedback `GainNode`. Max delay 1.0s.

### Reverb
```
in_gain → convolver_node → wet_gain
```
IR: algorithmically generated — `AudioBuffer` of white noise × exponential decay envelope. Generated at `init_audio`, regenerated when `decay` param changes.

### Distortion
```
in_gain → waveshaper_node → tone_filter(lowpass) → wet_gain
```
`WaveShaperNode` with tanh-shaped soft-clip curve (256 samples). `drive` controls curve hardness. `tone_filter` is a `BiquadFilter` (lowpass) with cutoff = `tone` Hz.

### Runtime switching (`set_fx_type`)
1. Disconnect old wet path nodes
2. Reconnect new effect nodes into wet path
3. Update `wet_gain.gain` based on mix

### Node hash keys
`create_web_audio_node` returns:
```ruby
{ in_gain:, out_gain:, dry_gain:, wet_gain:, delay:, fb_gain:, convolver:, waveshaper:, tone_filter: }
```
Unused keys are `nil` for inactive effect types.

`get_input(fx_node)` → `fx_node[:in_gain]`
`get_output(fx_node)` → `fx_node[:out_gain]`

### JS globals
No new JS globals needed. FX params are Ruby-side only. `_audioParamBatchUpdate` is unchanged.

## 3. UI Layout

Location: FM EDIT panel, below Filter section.

```
FX ──────────────────────────────────────
   Off  Echo  Reverb  Distortion   ← 4-way button group (data-param="fx_type")
   Mix ──────────────── 0.50       ← always visible

   [Echo params row:    Delay 0.20s   FB 0.40  ]  — visible only when Echo active
   [Reverb params row:  Decay 2.0s              ]  — visible only when Reverb active
   [Distortion row:     Drive 50   Tone 3000Hz  ]  — visible only when Distortion active
```

Parameter rows shown/hidden via CSS `display:none/block`. Ruby `on_param("fx_type", ...)` controls visibility via `el[:style][:display]`.

Active FX button gets `.active` CSS class → green highlight (same pattern as preset buttons).

Synth Patch Graph node label: `FX(echo)` / `FX(reverb)` / `FX(dist)` / `FX(off)`.

### data-param mapping

| Control | data-param | Range | Default |
|---------|-----------|-------|---------|
| FX type | `fx_type` | none/echo/reverb/distortion | none |
| Mix | `fx:mix` | 0.0–1.0 | 0.50 |
| Delay time | `fx:delay_time` | 0.05–1.0s | 0.20 |
| Feedback | `fx:feedback` | 0.0–0.95 | 0.40 |
| Decay | `fx:decay` | 0.5–4.0s | 2.0 |
| Drive | `fx:drive` | 1–100 | 50 |
| Tone | `fx:tone` | 500–8000Hz | 3000 |

## 4. Testing & Error Handling

### Unit tests (synth_patch_test.rb additions)
- `FxNode — DSL`: `.fx(:none)` creates node, correct default attrs
- `FxNode — JSON compilation`: type="fx", all param fields present
- `FxNode — signal chain`: `filter.fx(:echo).gain(:master)` chains correctly

### web-synth-test additions (Step 6)
- Click all 4 FX buttons → active state toggles correctly
- Mix slider change → no console errors
- Preset switch → FX path intact after rebuild

### Error handling
- Reverb IR generation failure: fall back to `wet_gain.gain = 0` (dry-only, silent fail)
- All `set_fx_type` / param update methods: `return unless @ctx` guard
- `disconnect` calls wrapped in `rescue nil` (same as existing `disconnect_all`)

### Preset integration
- All 4 presets default to `fx_type: :none`
- `PARAM_ATTRS` in main.rb extended with `"fx:fx_type"`, `"fx:mix"`, etc. for `sync_preset_ui`

## Files to Create / Modify

| File | Action |
|------|--------|
| `web/src/ruby/synth_patch/fx_node.rb` | Create — FxNode DSL class |
| `web/src/ruby/synth_patch/synth_patch.rb` | Modify — add `.fx` method |
| `web/src/ruby/synth_patch/web_adapter.rb` | Modify — fx node creation, set_fx_type, update_param cases |
| `web/src/ruby/preset_manager.rb` | Modify — add `.fx(:none)` to all 4 presets |
| `web/src/ruby/main.rb` | Modify — on_param fx_type handler, PARAM_ATTRS |
| `web/index.html` | Modify — FX UI section, Synth Patch Graph label |
| `web/src/ruby/synth_patch_test.rb` | Modify — FxNode tests |
| `web/test.html` | Modify — add fx_node.rb script tag |
