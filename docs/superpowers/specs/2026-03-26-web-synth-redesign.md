# Web Synth Redesign Spec

Date: 2026-03-26

## Overview

Comprehensive redesign of `web/index.html` and `web/src/ruby/` for a coherent Otamatone-inspired instrument UX.
Goal: tech-demo-worthy cockpit UI where all controls are always visible, with scale-snapped glide and FM preset exploration.

Does NOT conflict with `docs/superpowers/specs/2026-03-26-otmeiwa-emurator-design.md`:
- Emulator spec touches: `web/otmeiwa_emurator.html`, `web/server.rb`, `web/src/ruby/emulator/`
- This spec touches: `web/index.html`, `web/src/ruby/*.rb` (excluding emulator/)

## Design Principles

- **JS minimal**: Web API glue only (Serial / Audio / Canvas). All logic in Ruby.
- **Ruby shallow nesting**: flat conditionals, no deep class hierarchies.
- **DSL preserved**: `synth_patch/` DSL is the core for patch definition — untouched.
- **Extensible by addition**: adding PSG later = new Ruby file + new HTML panel. No refactor needed.

## Ruby File Structure

```
web/src/ruby/
├── serial.rb           # frame parser + connection state (merge of serial_protocol + serial_manager)
├── sensor_mapper.rb    # distance→MIDI note→Hz, accel→FM depth, scale snap, glide target
├── preset_manager.rb   # 4 presets defined with SynthPatch DSL
├── main.rb             # SynthApp orchestrator (shallow, flat)
└── synth_patch/        # DSL — no changes
```

`js_bridge.rb` is removed. JS calls go directly inline in `main.rb`.

## Ruby: serial.rb

Merges `serial_protocol.rb` + `serial_manager.rb` into one flat class.

Responsibilities:
- Parse `<D:NNN,AX:NNN,AY:NNN,AZ:NNN>` frames from a string buffer
- Track connection state (connected/disconnected)
- Maintain a small RX log (last N lines)

No error recovery logic — malformed frames are silently skipped. Parse errors are counted and exposed as `parse_error_count` for UI display.

## Ruby: sensor_mapper.rb

Extended with Otamatone-style note mapping. Flat methods, no subclasses.

```
distance_to_note(dist_mm, scale)  → MIDI note (36-84, snapped to scale)
note_to_freq(midi_note)           → Hz (equal temperament)
accel_to_fm_depth(ax, ay, az)     → 0.0-1.0
in_range?(dist_mm)                → bool
```

Scale snap: distance maps to MIDI note via log2 scale, then nearest note in the selected scale is chosen.

Scales: `:chromatic`, `:major`, `:minor`, `:pentatonic`

Glide: the note target is returned; JS applies `setTargetAtTime` with a user-controlled time constant.

## Ruby: preset_manager.rb

4 presets defined using the existing SynthPatch DSL. Each preset is a complete patch rebuild.

```
:otamatone  — triangle carrier + triangle mod, moderate FM depth. Wobbly character.
:clean      — sine carrier, no FM mod.
:acid       — sawtooth carrier + sine mod, high FM depth + lowpass filter sweep.
:retro      — square carrier, no FM.
```

Active preset is stored. `switch(name)` rebuilds and sends the patch to JS via `synthPatchBuild`.

## Ruby: main.rb

`SynthApp` as flat orchestrator. Registers JS callbacks. Handles `on_param_update` with a flat case statement.

Added param keys: `preset`, `scale`, `glide_time`, `fm_depth_manual`, `mod_ratio`, `carrier_wave`, `mod_wave`.

- `glide_time`: JS time constant in seconds for `setTargetAtTime` (default 0.3s)
- `fm_depth_manual`: additive offset to accel-derived FM depth (0–500). Accel still drives depth, manual slider adds to it.
- `mod_ratio`: modulator frequency = carrier frequency × mod_ratio (default 1.0)

No deep nesting. Each case is a single method call.

## JS (index.html)

Glue only:

| JS responsibility | Ruby responsibility |
|---|---|
| Web Serial connect/disconnect | — |
| Web Audio node wiring | — |
| Canvas draw loop (oscilloscope, level, sensor history) | — |
| `setTargetAtTime` for pitch + FM depth glide | NoteMapper provides target |
| Preset button click → `rubyOnParamUpdate('preset', name)` | preset switch + DSL rebuild |
| Slider `oninput` → `rubyOnParamUpdate(key, val)` | all param logic |

Removed from JS:
- Node editor click system (`renderNodePanel`, `npSlider`, `npApply`, `npSetFilterType`)
- `GNODES` click handling

Synth graph canvas remains as read-only visualization (no click interaction).

## UI Layout

Cockpit 2-column grid. All panels always visible, no expand/collapse.

```
┌─ SERIAL ─────────────────────────────────────────────────┐
│  ● CONNECTED 115200bps  [Disconnect]  [Init Audio] ▶ RUN │
│  Parse errors: 0                                         │
└──────────────────────────────────────────────────────────┘

┌─ PLAY ──────────────────────┐ ┌─ FM EDIT ───────────────┐
│ [Otamatone][Clean]          │ │ Carrier  [sine    ▼]    │
│ [Acid     ][Retro]          │ │ Mod      [triangle▼]    │
│ Scale  [Pentatonic ▼]       │ │ FM Depth [========] 200 │
│ Glide  [====] 300ms         │ │ Mod Ratio[========] 1.0 │
└─────────────────────────────┘ └─────────────────────────┘

┌─ SYNTH GRAPH ────────────────────────────────────────────┐
│  [FM Mod]──FM──>[FM Carrier]─>[Mixer]─>[Filter]─>[Master]─>🔊 │
└──────────────────────────────────────────────────────────┘

┌─ SENSOR ────────────────────┐ ┌─ AUDIO ─────────────────┐
│ Dist: 450mm  Note: A4 440Hz │ │ [oscilloscope canvas]   │
│ [distance sparkline]        │ │ [level meter canvas]    │
│ AX/AY/AZ bars               │ └─────────────────────────┘
└─────────────────────────────┘

┌─ ENVELOPE ──────────────────┐ ┌─ MAPPING ───────────────┐
│ Attack / Decay / Sustain /  │ │ Dist Min / Dist Max     │
│ Release sliders             │ │ Note Min / Note Max     │
└─────────────────────────────┘ │ Accel Scale             │
                                └─────────────────────────┘
```

Key changes from current UI:
- Serial status bar is always prominent (large, top of page)
- Parse error count visible in serial panel
- PLAY panel: preset buttons + scale dropdown + glide slider
- FM EDIT panel: carrier/mod waveform dropdowns + FM depth + mod ratio (always visible)
- Synth Graph: read-only, no click-to-edit
- Sensor panel shows MIDI note name alongside Hz
- MAPPING now uses Note Min/Max (MIDI 36-84) instead of Freq Min/Max

## Constraints

- Chrome only (Web Serial API, Web Audio API)
- `web/server.rb` not touched (emulator spec owns it)
- `web/otmeiwa_emurator.html` not created here
- `web/src/ruby/synth_patch/` not modified
- CSS includes `body { zoom: 1.5 }` for 150% display scale

## Out of Scope

- PSG synthesis (future: add `psg_patch.rb` + PSG panel to index.html)
- Auto-reconnect (deferred)
- otmeiwa.rb sensor-side changes (separate spec)
