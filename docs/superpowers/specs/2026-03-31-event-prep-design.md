# Event Prep Design: Three Performances

## Context

Three upcoming performance/submission deadlines:
- **2026-04-04**: RubyKaigi 2026 LT proposal submission
- **2026-04-19**: Joyful Meiwa performance
- **2026-04-24**: Pixiv event performance

Hardware verification against real `otmeiwa.rb` device is the critical path for all three.

## Principle

**Do not touch internal structure before deadlines.**
Functional fixes only. Refactoring = death flag before a deadline.

Priority: hardware verification > LT proposal > practice.

## Phases

### Phase 1 — WIP Commit (Claude, immediate)

Commit all pending changes as WIP without logic changes:
- `web/CLAUDE.md` — commit as-is (WIP, to be updated post-verification)
- `docs/superpowers/plans/2026-03-30-fx-effects.md` — commit untracked
- `docs/superpowers/specs/2026-03-30-fx-effects-design.md` — commit untracked

### Phase 2 — TODO.md Cleanup (Claude, immediate)

Remove stale items that are already implemented:
- Synth presets (otamatone/clean/acid/retro exist in preset_manager.rb)
- Smooth glide (20ms TC implemented and tuned)
- FM depth display (fm-depth-display span in index.html)
- C:M ratio slider (cm-ratio in index.html)
- Feedback slider (feedback in index.html)

Keep items that are genuinely pending or require hardware verification.

### Phase 3 — Hardware Verification (User)

User builds, flashes, and tests:
1. `rake build APP=otmeiwa` + `rake flash`
2. Connect Chrome via Web Serial
3. Sound output confirmed
4. LED behavior confirmed
5. Calibration behavior confirmed

Any failures → Claude fixes → user re-flashes.

### Phase 4 — Post-Verification Updates (Claude)

After hardware confirms working:
- Update `web/CLAUDE.md` with verified spec (JS helpers, frame rate, etc.)
- Fix LT Abstract: 「叩いて音が出るとたのしい」→「動かして音が出るとたのしい」

### Phase 5 — Submission (User)

User submits RubyKaigi LT proposal by 2026-04-04.

## Out of Scope

- Internal refactoring (`web_adapter.rb`, architecture)
- MIDI note quantization (contradicts web/CLAUDE.md "no quantization" policy)
- New filtering algorithms
- Any feature not needed for the three performances

## Hardware Test Checklist

- [ ] Serial frame output: `<D:NNNN,AX:NNNN,AY:NNNN,AZ:NNNN>`
- [ ] Chrome Web Serial connect/disconnect
- [ ] Sound on/off via button
- [ ] Pitch changes with distance (30–570mm range)
- [ ] FM depth changes with acceleration (shake)
- [ ] LED hue tracks distance
- [ ] Calibration button: accel baseline resets on press
- [ ] FX controls: Off/Echo/Reverb/Distortion buttons
- [ ] Preset switching: otamatone/clean/acid/retro
