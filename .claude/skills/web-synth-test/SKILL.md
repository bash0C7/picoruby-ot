---
name: web-synth-test
description: Automated Chrome smoke test for the picoruby-ot web synthesizer. Use this skill whenever you need to verify the synth works after code changes — it starts the web server if needed, opens Chrome, and runs a full automated test sequence: Ruby VM boot, Init Audio, preset buttons, FM Edit controls (C:M ratio, feedback), Test Mode sensor simulation with FM depth display check, and error checks. Trigger on "test the synth", "smoke test", "verify web synth", "check the browser synth", or after any changes to index.html / web/src/ruby/*.rb.
user-invocable: true
---

# Web Synth Automated Test

Runs a Chrome-based smoke test of the picoruby-ot synthesizer at `http://localhost:8000/index.html`.

## Test Sequence

Run steps 1–9 in order. Report a ✅/❌ result for each check.

---

### Step 1: Ensure server is running

```bash
cd /Users/bash/dev/src/github.com/bash0C7/picoruby-ot && rake server:status
```

If not running, start it:

```bash
rake server:start
```

Wait 2 seconds after start before proceeding.

---

### Step 2: Open Chrome with cache-busting URL

Use `mcp__claude-in-chrome__tabs_context_mcp` to get/create a tab, then navigate:

```
URL: http://localhost:8000/index.html?v=<timestamp>
```

Replace `<timestamp>` with `Date.now()` equivalent (e.g. current epoch seconds).

After navigation, call `mcp__claude-in-chrome__read_console_messages` with `clear: true` to reset the log.

---

### Step 3: Wait for Ruby VM ready (max 30s)

Poll `mcp__claude-in-chrome__read_console_messages` with `pattern: "Ruby|ruby|error|Error"` every 3 seconds until:

- **PASS**: `[Ruby] picoruby-ot synth ready!` appears → ✅ Ruby VM started
- **FAIL**: `[Ruby] Fatal:` or `EXCEPTION` appears → ❌ Ruby error (capture message)
- **TIMEOUT**: 30s elapsed without ready message → ❌ Timeout

If FAIL or TIMEOUT, capture full console output and stop — remaining tests are meaningless.

---

### Step 4: Check cockpit UI layout

Take a screenshot with `mcp__claude-in-chrome__computer action:screenshot`.

Visually verify:
- ✅ 2-column grid visible: left=PLAY panel, right=FM EDIT panel
- ✅ "Otamatone" preset button is highlighted green (active)
- ✅ "Parse errors: 0" visible
- ✅ Synth Patch Graph canvas shows placeholder text "Init Audio to build synth patch graph"
- ✅ Audio Monitor shows "Init Audio to enable oscilloscope"
- ✅ Header sensor row contains `FM:` span (value `0.00` before Init Audio)
- ✅ Controls panel contains **C:M** slider (range 0.1–8.0, default 1.00)
- ✅ Controls panel contains **FB** slider (range 0.0–1.0, default 0.00)

---

### Step 5: Click "Init Audio" and verify

Find the button with `mcp__claude-in-chrome__find query:"Init Audio button"` and click it.

Take a screenshot. Verify:
- ✅ Audio status badge changes from `audio off` → `running`
- ✅ Synth Patch Graph now shows: FM Mod → FM Carrier → Mixer → Filter → Master → 🔊
- ✅ Console logs `[SynthPatch] built: fm_mod, fm_carrier, mixer, filter, master`
- ✅ Oscilloscope canvas is visible (not just placeholder text)

---

### Step 6: Test all preset buttons

For each preset in order: **Clean → Acid → Retro → Otamatone**

For each:
1. Find and click the button
2. Wait 0.5s, then take a screenshot
3. Verify:
   - ✅ Clicked button is highlighted green (active), others are not
   - ✅ Carrier/Mod waveform dropdowns update to preset defaults:
     - Otamatone: carrier=triangle, mod=triangle
     - Clean: carrier=sine, mod=sine
     - Acid: carrier=sawtooth, mod=sine
     - Retro: carrier=square, mod=square
   - ✅ Synth graph Filter label updates (Otamatone=1200Hz, Clean=4000Hz, Acid=600Hz, Retro=2000Hz)
   - ✅ Console shows `[SynthPatch] built:` for each switch

---

### Step 7: Test Mode — sensor simulation

Scroll to the bottom of the page to find the **Test Mode (no hardware)** section.

1. Click **Test Connect**
2. Verify:
   - ✅ Serial status badge changes to `connected at 115200bps`
   - ✅ "Test Connect" button becomes disabled, "Test Stop" / "Loop" / "Send Once" become enabled

3. Move the **Dist mm** slider to a value other than 450 (e.g. 200), then click **Send Once**
4. Verify in **Sensor Monitor** and header:
   - ✅ `Dist mm` updates to the slider value
   - ✅ `Note` updates (e.g. G#3)
   - ✅ `Freq Hz` updates accordingly
   - ✅ Header `FM:` value updates (non-zero if AX/AY/AZ sliders are non-zero)

5. Move **AX** slider to a non-zero value (e.g. 500), click **Send Once**
6. Verify:
   - ✅ Header `FM:` shows a value > 0.00

7. Click **Loop** — button label changes to "Stop Loop"
8. Move **Dist mm** slider while loop is running
9. Verify:
   - ✅ `Dist mm`, `Note`, `Freq Hz` values update continuously
   - ✅ Header `FM:` updates continuously
   - ✅ Oscilloscope canvas animates (waveform visible)
   - ✅ Level meter shows activity

10. Click **Stop Loop** → updates stop
11. Click **Test Stop** → serial status returns to `disconnected`

---

### Step 8: Test C:M ratio and Feedback sliders

With Init Audio still active (click Test Connect again if needed):

1. Find the **C:M** slider in the controls panel. Move it to **2.00**
2. Verify:
   - ✅ Label next to slider shows `2.00`
   - ✅ No JS errors in console

3. Move **C:M** slider to **0.50**
4. Verify:
   - ✅ Label shows `0.50`
   - ✅ No JS errors

5. Move **C:M** slider back to **1.00**

6. Find the **FB** (feedback) slider. Move it to **0.50**
7. Verify:
   - ✅ Label shows `0.50`
   - ✅ No JS errors

8. Move **FB** slider back to **0.00**

9. Switch preset to **Otamatone**, then move **C:M** to **2.00** and **FB** to **0.30**
10. Verify:
    - ✅ No JS errors — feedback path rewired correctly after preset switch

---

### Step 9: Check for console errors

Call `mcp__claude-in-chrome__read_console_messages` with `pattern: "error|Error|EXCEPTION|Fatal|NameError|TypeError"`.

- ✅ No error messages → clean run
- ❌ Any errors found → list them

---

## Reporting

After all steps, output a summary table:

```
## Web Synth Test Results

| # | Check | Result |
|---|-------|--------|
| 1 | Server running | ✅ |
| 2 | Page loaded | ✅ |
| 3 | Ruby VM ready | ✅ |
| 4 | Cockpit UI layout (incl. FM:/C:M/FB) | ✅ |
| 5 | Init Audio + graph | ✅ |
| 6 | Preset buttons (4/4) | ✅ |
| 7 | Test Mode sensor simulation + FM depth | ✅ |
| 8 | C:M ratio + FB sliders | ✅ |
| 9 | No console errors | ✅ |

**PASSED 9/9**
```

If any check failed, include the failure detail below the table.

## Notes

- Tests run in ~45–75s total (ruby.wasm init takes ~10s on first load)
- Cache-busting URL prevents stale ruby.wasm bytecode from causing `SerialManager` errors
- If Ruby VM fails with `uninitialized constant`, the old bytecode is cached — the `?v=<timestamp>` URL forces a fresh load
- Test Mode feeds synthetic `<D:NNN,AX:NNN,AY:NNN,AZ:NNN>\n` frames via `rubySerialOnReceive()` — same data path as real hardware
- Real serial (Web Serial API) takes priority over Test Mode — if `_port` is set, Test Connect does nothing
