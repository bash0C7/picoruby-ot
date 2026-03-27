# Web Synth Redesign Implementation Plan

**Goal:** Redesign the Chrome web synth into a cockpit-style Otamatone instrument with scale-snap glide, FM preset exploration, and simplified Ruby internals.

**Architecture:** 4 flat Ruby files (serial.rb, sensor_mapper.rb, preset_manager.rb, main.rb) + unchanged synth_patch/ DSL. JS is glue-only. UI is a 2-column always-visible cockpit with 150% zoom.

**Tasks 1–6: ✅ COMPLETE** (commits e3801fb–a0657d2)

---

## Task 7: Chrome Smoke Test

Open `http://localhost:8000/index.html?v=1` in Chrome. Use `rake web` to start the server first.

- [ ] **Check: page loads at 150% zoom, cockpit 2-column layout visible**

Expected: two columns visible (PLAY | FM EDIT), all panels visible, no expand needed.

- [ ] **Check: Ruby VM starts**

Open DevTools → Console. Expected log:
```
[Ruby] starting picoruby-ot synth...
[SynthPatch] built: fm_mod, fm_carrier, mixer, filter, master
[Ruby] picoruby-ot synth ready!
```

- [ ] **Check: Init Audio → synth graph renders**

Click "Init Audio". Expected: `ast` shows "running", synth graph canvas shows FM Mod → FM Carrier → Mixer → Filter → Master → 🔊.

- [ ] **Check: preset buttons**

Click each preset button (Otamatone / Clean / Acid / Retro). Expected: active button turns green, Console logs `[SynthPatch] built:` each time, carrier/mod dropdowns update to preset defaults.

- [ ] **Check: FM Edit sliders**

Move FM Depth slider. Expected: audible FM depth change (if audio active). Move Mod Ratio slider. Expected: modulator pitch changes relative to carrier.

- [ ] **Check: Scale + Glide**

Set Scale to "Major". Move Glide slider to 1000ms. Expected (with hardware): note changes slide slowly between major-scale notes only.

- [ ] **Check: parse error display**

Parse errors counter shows 0 on clean connection. Any malformed serial data increments the counter.

- [ ] **Check: oscilloscope + level meter**

With audio active, oscilloscope shows waveform, level meter responds to volume. Both visible without scrolling.
