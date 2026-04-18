# Event Prep Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stabilize the project for three upcoming performances (RubyKaigi LT 4/4, Joyful Meiwa 4/19, Pixiv event 4/24) with zero internal refactoring.

**Architecture:** Docs-first WIP commit → TODO.md cleanup → user hardware verification → post-verification doc/LT updates. All changes are additive or text-only until hardware is confirmed.

**Tech Stack:** git, Markdown, PicoRuby (otmeiwa.rb), Chrome Web Synth (ruby.wasm + Web Audio)

---

### Task 1: WIP Commit — pending docs

**Files:**
- Modify: `web/CLAUDE.md` (staged as-is, WIP)
- New: `docs/superpowers/specs/2026-03-30-fx-effects-design.md` (untracked)
- New: `docs/superpowers/plans/2026-03-30-fx-effects.md` (untracked)
- New: `docs/superpowers/specs/2026-03-31-event-prep-design.md` (just created)
- New: `docs/superpowers/plans/2026-03-31-event-prep.md` (this file)

- [ ] **Step 1: Commit all pending docs as WIP**

```bash
git add web/CLAUDE.md \
  docs/superpowers/specs/2026-03-30-fx-effects-design.md \
  docs/superpowers/plans/2026-03-30-fx-effects.md \
  docs/superpowers/specs/2026-03-31-event-prep-design.md \
  docs/superpowers/plans/2026-03-31-event-prep.md
git commit -m "docs: commit WIP docs — fx-effects plan/spec, event-prep plan/spec"
```

---

### Task 2: TODO.md — remove stale completed items

**Files:**
- Modify: `TODO.md`

Items to remove (already implemented):
- `otmeiwa_emurator 動作確認` section — emulator approach replaced by real hardware test
- `Smooth glide` item — 20ms TC implemented and tuned (web/CLAUDE.md confirmed)
- `シンセプリセット` item — 4 presets exist: otamatone/clean/acid/retro in `preset_manager.rb`
- `MIDI note quantization` item — explicitly decided against in `web/CLAUDE.md` ("no note quantization, no scale snap")

- [ ] **Step 1: Remove `otmeiwa_emurator` section from TODO.md**

Delete these lines from `TODO.md`:
```
## ★★ otmeiwa_emurator 動作確認（最優先）

- [ ] **通しテスト**: `ruby web/otmeiwa_emurator.rb` → Chrome に Connect → `loop_emit` → 音出し確認
  - `ruby web/otmeiwa_emurator.rb` を起動して表示された `/dev/ttysXXX` を Chrome で接続
  - `index.html` を開いて Connect → Init Audio
  - `loop_emit(d: 450, ax: 0, ay: 0, az: 0)` で音が出ることを確認
  - `sweep(:d, 20, 900)` で音程スイープを確認

---
```

- [ ] **Step 2: Remove `Smooth glide` item from TODO.md**

Delete these lines:
```
- [ ] **Smooth glide**: 音程変化のglide time設定（theremin的な滑らかさ）
  - 現状 50ms time constant、もっと長くして滑らかに
```

- [ ] **Step 3: Remove `シンセプリセット` item from TODO.md**

Delete these lines:
```
- [ ] **シンセプリセット**: ボタン1発で音色切り替え
  - "Clean" — FMなし、サイン波のみ
  - "FM Light" — 軽いFM変調
  - "FM Heavy" — 深いFM変調（現状に近い）
  - "Acid" — ノコギリ波 + フィルター
```

- [ ] **Step 4: Remove `MIDI note quantization` item from TODO.md**

Delete these lines:
```
- [ ] **MIDI note quantization**: 距離→MIDIノート番号変換（semitone snap）
  - 距離レンジ(20〜900mm) → MIDI note 36-84 (C2-C6, 4オクターブ)
  - log2スケールで等音程感を出す
  - スケール選択UI: クロマチック / ペンタトニック / メジャー / マイナー
```

- [ ] **Step 5: Add real hardware test section at the top of TODO.md**

Replace the removed `★★` section with:
```markdown
## ★★ 実機確認チェックリスト（最優先）

- [ ] `rake build APP=otmeiwa` → `rake flash` → Chrome Web Serial 接続
- [ ] `<D:NNNN,AX:NNNN,AY:NNNN,AZ:NNNN>` フレームが流れることを確認
- [ ] Init Audio → 音が出ることを確認
- [ ] 距離 30–570mm で音程変化を確認
- [ ] 加速度（シェイク）で FM depth 変化を確認
- [ ] LED hue が距離に追従することを確認
- [ ] ボタン押下でサウンドON/OFF + キャリブレーション確認
- [ ] FX切り替え (Off/Echo/Reverb/Distortion) 確認
- [ ] プリセット切り替え (otamatone/clean/acid/retro) 確認

---
```

- [ ] **Step 6: Commit**

```bash
git add TODO.md
git commit -m "docs: update TODO.md — remove stale items, add real hardware checklist"
```

---

### Task 3: Post-hardware — update web/CLAUDE.md (run AFTER hardware verified)

> **Wait for user to complete hardware verification before this task.**

**Files:**
- Modify: `web/CLAUDE.md`

After hardware confirms the actual behavior, update `web/CLAUDE.md` to reflect reality:

- [ ] **Step 1: Verify JS helpers still exist in index.html**

```bash
grep -n "_createReverbIR\|_createDistortionCurve" web/index.html
```

Expected: lines 834 and 851 (or nearby).

- [ ] **Step 2: Decide: add or keep removed from JS Minimalism Policy**

If `_createReverbIR` and `_createDistortionCurve` exist in `web/index.html`, restore them to the JS Minimalism Policy section in `web/CLAUDE.md`:

```markdown
6. `_createReverbIR(decay)` helper (ConvolverNode impulse response buffer generation)
7. `_createDistortionCurve(drive)` helper (WaveShaperNode curve generation)
8. Memory monitor
```

(Renumber the existing `6. Memory monitor` to `8.`)

- [ ] **Step 3: Update frame rate if different from documented 40fps**

Check actual hardware frame rate. If it differs from `~40fps (~25ms interval)` in web/CLAUDE.md, update the Portamento Implementation section.

- [ ] **Step 4: Commit**

```bash
git add web/CLAUDE.md
git commit -m "docs: update web/CLAUDE.md with verified hardware spec"
```

---

### Task 4: Post-hardware — fix LT Abstract (run AFTER hardware verified)

> **Wait for user to complete hardware verification before this task.**

**Files:**
- Modify: RubyKaigi LT proposal (external submission, not in repo)

- [ ] **Step 1: Change Abstract closing line**

Find:
```
「叩いて音が出るとたのしい！」
```

Replace with:
```
「動かして音が出るとたのしい！」
```

Rationale: The instrument is a theremin-style distance controller, not a percussion instrument. "動かして" aligns with the actual demo (distance-based pitch change).

- [ ] **Step 2: Verify all technical claims still hold**

Cross-check Abstract/Details against implementation:

| Claim | Verified by |
|-------|-------------|
| PicoRuby controller + PC synth separation | `otmeiwa.rb` + `web/index.html` |
| 115200bps serial (3.7× MIDI 31kbps) | `src_components/R2P2-ESP32/CLAUDE.md` |
| EMA noise filtering (alpha=50) | `otmeiwa.rb` line 42: `DISTANCE_SMOOTH_ALPHA = 50` |
| Chattering prevention | `otmeiwa.rb` line 122: `debounce: 100` |
| Calibration on button press | `otmeiwa.rb` line 67: `toggle_sound` sets baseline |
| Portable USB power | ATOM Matrix hardware fact |
| Live demo at 4/19 | Joyful Meiwa performance plan |

- [ ] **Step 3: Submit LT proposal by 2026-04-04**
