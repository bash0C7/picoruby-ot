# Joyful Meiwa Event Prep Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare びことん (otmeiwa.rb + Chrome Web Synth) for exhibition and live Korobeiniki performance at Joyful Meiwa on 2026-04-19.

**Architecture:** Three parallel workstreams — (1) software verification + bug fixes, (2) project README + slide 4 content, (3) Korobeiniki settings + practice guide. All must be done by 2026-03-29 for the releasable milestone.

**Tech Stack:** PicoRuby/mruby on ATOM Matrix ESP32, ruby.wasm + Web Audio API (Chrome), Web Serial API, WS2812 LEDs

---

## Part 1: Development — Software Verification

### Task 1: Run smoke test and capture baseline

**Files:**
- Read: `web/index.html`
- Use: `web-synth-test` skill

- [ ] **Step 1: Start web server**

```bash
cd /Users/bash/dev/src/github.com/bash0C7/picoruby-ot/web
ruby -run -ehttpd . -p8000 &
```

Expected: server starts at http://localhost:8000

- [ ] **Step 2: Run smoke test skill**

Use the `web-synth-test` skill to run the full automated test sequence.
Expected: All 8 steps pass (Ruby VM boot, Init Audio, preset buttons, FM Edit controls, Test Mode, error checks).

- [ ] **Step 3: Record any failures**

If any step fails, note the exact error and affected component.
If all pass: proceed to Task 2.
If failures: fix the root cause before proceeding (do not skip).

- [ ] **Step 4: Commit if fixes were made**

```bash
git add web/index.html web/src/ruby/*.rb
git commit -m "fix: resolve smoke test failures"
```

---

### Task 2: Verify scale snap with Korobeiniki settings

The web synth's Sensor Mapping panel has sliders for Dist Min/Max and Note Min/Max. Verify scale snap works correctly for melody performance.

**Files:**
- Read: `web/src/ruby/sensor_mapper.rb`
- Read: `web/src/ruby/main.rb`

- [ ] **Step 1: Verify SensorMapper scale snap logic**

Open `web/src/ruby/sensor_mapper.rb`. Confirm `snap_to_scale` finds the nearest scale note by iterating all `@scale_notes`. Confirm `build_scale_notes` filters `@midi_min..@midi_max` against the pattern.

Expected: `snap_to_scale` returns the closest note in `@scale_notes`, no off-by-one issues.

- [ ] **Step 2: Manually calculate Korobeiniki note positions**

With these settings (verified playable):
- `dist_min=20`, `dist_max=300` → 280mm range
- `midi_min=57` (A3), `midi_max=71` (B4)
- `scale=major` (C major pattern = A natural minor notes)

The 9 scale notes and their approximate center distances:

| Note | MIDI | Dist (mm) | Snap zone (mm) |
|------|------|-----------|----------------|
| A3   | 57   | 20        | 20–40          |
| B3   | 59   | 60        | 40–70          |
| C4   | 60   | 80        | 70–100         |
| D4   | 62   | 120       | 100–140        |
| E4   | 64   | 160       | 140–170        |
| F4   | 65   | 180       | 170–200        |
| G4   | 67   | 220       | 200–240        |
| A4   | 69   | 260       | 240–280        |
| B4   | 71   | 300       | 280–300        |

Formula: `dist = 20 + (midi - 57) / 14.0 * 280`

Verify this math is consistent with `SensorMapper#distance_to_note`:
```ruby
# ratio = (dist - dist_min) / (dist_max - dist_min)
# raw = midi_min + (ratio * span).to_i
# For E4(64): ratio = (160 - 20) / 280 = 0.5, raw = 57 + (0.5 * 14).to_i = 57 + 7 = 64 ✓
```

- [ ] **Step 3: Test scale snap in browser (Test Mode)**

Open http://localhost:8000/index.html in Chrome.
Set: Scale=Major, Dist Min=20, Dist Max=300, Note Min=57, Note Max=71, Glide ms=150.

Use Test Mode → send D=160 (should snap to E4/64/330Hz).
Send D=60 (should snap to B3/59/247Hz).
Send D=80 (should snap to C4/60/262Hz).

Check `Sensor Monitor → Note` display for correct values.

- [ ] **Step 4: Fix if snap is incorrect**

If snap produces wrong notes, check `build_scale_notes` and `snap_to_scale` in `sensor_mapper.rb`.
Common issues:
- Off-by-one in `midi_max` boundary: `(@midi_min..@midi_max)` is inclusive, should be correct.
- Wrong pattern: `major: [0,2,4,5,7,9,11]` — A3(57) is 57%12=9 → in pattern ✓

- [ ] **Step 5: Commit if fixes were made**

```bash
git add web/src/ruby/sensor_mapper.rb
git commit -m "fix: correct scale snap for melody performance"
```

---

### Task 3: Stability check (30-minute continuous run)

**Files:**
- Use: `web-synth-test` skill (Test Mode loop)

- [ ] **Step 1: Start Test Mode loop**

Open http://localhost:8000/index.html in Chrome.
Click Test Mode → Test Connect → Loop.
This simulates continuous sensor data at ~20fps.

- [ ] **Step 2: Monitor for 10 minutes**

Watch Chrome DevTools console for:
- JavaScript errors
- Memory growth (check DevTools → Memory tab if available)
- Audio dropouts (oscilloscope canvas stops updating)

- [ ] **Step 3: Check parse error count**

After 10 minutes, check `Parse errors:` count in the Serial section.
Expected: 0 errors (Test Mode sends valid frames).
If errors > 0: investigate `serial_protocol.rb` frame parser.

- [ ] **Step 4: Fix any stability issues**

If crash/error: check DevTools console for the exact error message. Fix root cause.
If ruby.wasm memory leak: check for unbounded array growth in `serial_manager.rb` rx_log.

- [ ] **Step 5: Commit fixes if any**

```bash
git add web/src/ruby/serial_manager.rb
git commit -m "fix: prevent memory leak in rx_log buffer"
```

---

## Part 2: Documentation

### Task 4: Create root README.md

No README.md exists at the project root. The QR codes on the exhibit panels link to the GitHub repo. Visitors need to understand the project.

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README.md**

Create `/Users/bash/dev/src/github.com/bash0C7/picoruby-ot/README.md`:

```markdown
# picoruby-ot: びことん

A software musical instrument inspired by Maywa Denki's Otamatone.

Distance sensor controls pitch. Shake the stick for FM synthesis effects.
Built with M5 ATOM Matrix (ESP32) + PicoRuby + Chrome Web Audio.

## Hardware

- M5 ATOM Matrix (ESP32-PICO-D4)
- Unit ToF (VL53L0X laser distance sensor)
- USB cable to PC running Chrome

## How it works

1. Flash `otmeiwa.rb` to ATOM Matrix via R2P2-ESP32
2. Open `web/index.html` in Chrome (serve with `cd web && ruby -run -ehttpd . -p8000`)
3. Click Connect, select the ATOM Matrix serial port (115200bps)
4. Hold the sensor and move your hand — distance controls pitch

## Architecture

```
ATOM Matrix (otmeiwa.rb)
  VL53L0X distance sensor → USB Serial 115200bps
    ↓ <D:NNNN,AX:NNNN,AY:NNNN,AZ:NNNN>
Chrome (web/index.html)
  ruby.wasm → SensorMapper → FM Synthesizer (Web Audio API)
```

## Build

See `src_components/R2P2-ESP32/CLAUDE.md` for build instructions.
Requires: ESP-IDF toolchain, R2P2-ESP32 firmware.
```

- [ ] **Step 2: Commit README**

```bash
git add README.md
git commit -m "docs: add root README for GitHub exhibit QR code"
```

---

### Task 5: Slide 4 content review

Slide 4 (Synthesizer) is the incomplete panel. Verify its content matches the current codebase.

**Files:**
- Read: `web/src/ruby/main.rb`
- Read: `web/src/ruby/sensor_mapper.rb`
- Read: `web/src/ruby/preset_manager.rb`

- [ ] **Step 1: Verify slide 4 architecture elements**

Current synthesizer components (confirm these are in the slide):

```
オレオレプロトコル (SerialProtocol)
  ↓ frame parse <D:,AX:,AY:,AZ:>
音域生成 (SensorMapper)
  distance_to_note → MIDI snap → Hz
  accel_to_fm_depth
  ↓
プリセット (PresetManager: otamatone / clean / acid / retro)
  SynthPatch DSL → FM carrier + modulator
  ↓
WebAudio API
  OscillatorNode (carrier + modulator)
  BiquadFilterNode → GainNode → AnalyserNode → destination
  ↓
出力 (oscilloscope + level meter + patch graph)
```

- [ ] **Step 2: Check for missing elements in slide 4**

Elements that MUST be in slide 4 (check against your printed draft):
- [ ] SynthPatch DSL box (ruby.wasm側)
- [ ] 4 presets listed: otamatone, clean, acid, retro
- [ ] FM synthesis signal path: carrier ← modulator → frequency AudioParam
- [ ] Scale snap: distance → MIDI note → Hz (equal temperament)
- [ ] `ruby.wasm` label (distinguishes from native Ruby)

- [ ] **Step 3: Note any discrepancies for human to fix in slides app**

Write a text file with corrections needed:
Create `docs/slide4-corrections.txt` with any found gaps.
Format: `MISSING: [element description]` or `OUTDATED: [old text] → [new text]`

- [ ] **Step 4: Commit corrections file**

```bash
git add docs/slide4-corrections.txt
git commit -m "docs: add slide 4 correction notes for A3 printing"
```

---

## Part 3: Practice Setup

### Task 6: Korobeiniki performance guide

**Files:**
- Create: `docs/korobeiniki-practice-guide.md`

- [ ] **Step 1: Write practice guide with web synth settings**

Create `/Users/bash/dev/src/github.com/bash0C7/picoruby-ot/docs/korobeiniki-practice-guide.md`:

```markdown
# Korobeiniki (Tetris Theme) Practice Guide

## Web Synth Settings

Set these before each practice session:

| Control | Value | Location |
|---------|-------|----------|
| Preset | Retro | Play panel |
| Scale | Major | Play panel |
| Glide ms | 150 | Play panel |
| Dist Min | 20 | Sensor Mapping |
| Dist Max | 300 | Sensor Mapping |
| Note Min | 57 | Sensor Mapping |
| Note Max | 71 | Sensor Mapping |

## Note Positions (distance from sensor face)

Hold the stick so the sensor faces your palm. Distance = gap between sensor and hand.

| Note | Name | Distance | Marker |
|------|------|----------|--------|
| A3   | ラ(低) | 20mm  | very close |
| B3   | シ    | 60mm  | tape mark 1 |
| C4   | ド    | 80mm  | tape mark 2 |
| D4   | レ    | 120mm | tape mark 3 |
| E4   | ミ    | 160mm | tape mark 4 |
| F4   | ファ  | 180mm | tape mark 5 |
| G4   | ソ    | 220mm | tape mark 6 |
| A4   | ラ    | 260mm | tape mark 7 |
| B4   | シ(高)| 300mm | tape mark 8 |

Snap zones are ~30mm wide — you have ±15mm of margin per note.

## Physical Markers

Apply colored tape to the stick at each snap center:
- 60mm (B3), 80mm (C4), 120mm (D4), 160mm (E4), 180mm (F4), 220mm (G4), 260mm (A4)

Use different colors for: low (blue), middle (yellow), high (red).

## Korobeiniki Melody

### Phrase 1 (refrain) — start here
```
ミ(160) シ(60) ド(80) レ(120) ミ(160) ミ(160) ミ(160)
レ(120) レ(120) レ(120) ミ(160) ソ(220) ソ(220)
```

### Phrase 2
```
ラ(260) ミ(160) ミ(160) ミ(160)
レ(120) レ(120) レ(120) ミ(160) レ(120) ド(80)
シ(60) シ(60) シ(60)
```

### Phrase 3 (B section)
```
ド(80) レ(120) ミ(160) ラ(低)(20) ラ(低)(20)
レ(120) ミ(160) ファ(180) ミ(160) ミ(160)
ド(80) レ(120) ミ(160) ラ(低)(20) ラ(低)(20)
レ(120) ミ(160) ファ(180) ミ(160) ド(80)
```

## Practice Schedule

### Phase 1 (2026-03-30 to 04-05): Phrase 1 only
- Session: 15 min/day
- Goal: Play Phrase 1 at BPM 60 without mistakes 3 times in a row
- Method: One note at a time → two notes → full phrase

### Phase 2 (2026-04-06 to 04-12): Full song
- Session: 20 min/day
- Goal: Play all 3 phrases at BPM 80 end-to-end
- Milestone check (2026-04-12): Record one take, 60%+ pitch accuracy is pass

### Event day tips
- Before the demo: play Phrase 1 alone 5 times as warm-up
- If you lose position: stop, find E4 (160mm center), restart from there
- It's OK to be slow — audience cares about the concept, not BPM
```

- [ ] **Step 2: Commit practice guide**

```bash
git add docs/korobeiniki-practice-guide.md
git commit -m "docs: add Korobeiniki practice guide with note positions"
```

---

## Releasable Milestone Checklist (2026-03-29)

All must be true before pushing to GitHub:

- [ ] Smoke test passes (Task 1)
- [ ] Scale snap verified for Korobeiniki settings (Task 2)
- [ ] 10-minute stability run: 0 parse errors, no crashes (Task 3)
- [ ] README.md exists at project root with QR-ready content (Task 4)
- [ ] Slide 4 corrections documented (Task 5)
- [ ] Korobeiniki practice guide committed (Task 6)
- [ ] Human: print one A3 test page, verify fonts and diagrams are readable (not pixelated)
- [ ] Human pushes branch to GitHub (ask user before pushing)
