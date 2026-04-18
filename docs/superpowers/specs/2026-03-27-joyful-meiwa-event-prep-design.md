# Joyful Meiwa Event Preparation Design

**Event**: Joyful Meiwa (ジョイフル明和) — April 19, 2026
**Venue**: Maywa Denki Atelier, Musashikoyama
**Exhibit name**: bash軟件
**Device**: びことん (otmeiwa.rb + Chrome Web Synth)

---

## Goals

| Date | Milestone |
|------|-----------|
| 2026-03-29 | Releasable — software stable, slides finalized, GitHub ready |
| 2026-04-12 | Practice complete (1 week buffer before event) |
| 2026-04-19 | Live event |

---

## Section 1: Development (2026-03-28 to 03-29)

Scope: bug fixes only. No new features.

### Tasks

1. **Smoke test** — run `web-synth-test` skill to confirm current working state
2. **Scale snap verification** — confirm `sensor_mapper.rb` scale snap works correctly for melody use
3. **Stability check** — confirm no crashes during extended connection (serial disconnect, memory)
4. **Distance range review** — current `DIST_VALID_MIN=20, MAX=900` in `otmeiwa.rb`; confirm range is appropriate for stick performance (~20–300mm usable playing range)

### Success criteria

- web-synth-test passes all steps with no errors
- Scale snap produces stable discrete notes when distance is held steady
- No crash or audio dropout during 30-minute continuous run

---

## Section 2: Slides (2026-03-28 to 03-29, parallel with development)

4 x A3 panels already drafted. Completion tasks:

1. **Finalize slide 4 (Synthesizer)** — currently highlighted/incomplete; confirm architecture content matches current codebase
2. **QR codes** — ensure GitHub repository URL is correct and README is informative enough for "reproduce at home" promise
3. **Device name consistency** — confirm "びことん" used consistently across all 4 slides
4. **Print check** — verify font sizes and diagram resolution survive A3 printing

### Slide content (existing structure, no changes to layout)

| Panel | Content |
|-------|---------|
| 1 | Title + device photo + QR code ("reproducible at home") |
| 2 | Overall architecture (Controller ↔ Synthesizer) |
| 3 | Controller detail (otmeiwa.rb flow) |
| 4 | Synthesizer detail (Web Synth architecture) |

### Success criteria

- All 4 slides print cleanly at A3
- QR code links to GitHub repo with working README
- Slide 4 content is accurate and complete

---

## Section 3: Practice (2026-03-30 to 04-12)

Target song: Korobeiniki (Tetris theme)

### Phase 1 — Position Mastery (03-30 to 04-05)

- Map distance positions to notes (which distance = which note)
- Apply physical markers (tape) to stick or stand as position guides
- Focus on 8-note refrain only: `Mi・Re・Do・Re・Mi・Mi・Mi` — slow repetition

### Phase 2 — Full Song (04-06 to 04-12)

- Slow-tempo run-through at BPM 80 (down from 120)
- Expand from refrain to A-section once refrain is stable
- One practice session simulating event context: "explain while playing" to a listener

### Success criteria

| Date | Criteria |
|------|----------|
| 2026-03-29 | 8-note refrain plays in correct scale (confirms snap works with hardware) |
| 2026-04-12 | 1 chorus of Korobeiniki playable end-to-end (60%+ pitch accuracy acceptable) |
| 2026-04-19 | Refrain reliable; full song best-effort |

---

## Out of scope

- New synthesizer features
- New LED patterns
- Hardware modifications
- Second device (rhythm device) — separate exhibit component, not covered here
