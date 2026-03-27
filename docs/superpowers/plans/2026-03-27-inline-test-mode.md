# Inline Test Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the external emulator (HTTP polling) with inline test controls directly in index.html so sound can be tested without hardware or extra processes.

**Architecture:** Add a "Test Mode" section to index.html that builds `<D:NNN,AX:NNN,AY:NNN,AZ:NNN>\n` frames from sliders and injects them into `rubySerialOnReceive()` — the exact same path as real Web Serial data. The emulator files and skill are deleted.

**Tech Stack:** HTML range inputs, vanilla JS `setInterval`, existing `rubySerialOnConnect` / `rubySerialOnReceive` / `rubySerialOnDisconnect` JS callbacks (registered by ruby.wasm)

---

### Task 1: Delete emulator files and skill

**Files:**
- Delete: `web/otmeiwa_emurator.rb`
- Delete: `.claude/skills/otmeiwa-emurator/SKILL.md`

- [ ] **Step 1: Delete emulator Ruby file**

```bash
rm /Users/bash/dev/src/github.com/bash0C7/picoruby-ot/web/otmeiwa_emurator.rb
```

- [ ] **Step 2: Delete emulator skill directory**

```bash
rm -rf /Users/bash/dev/src/github.com/bash0C7/picoruby-ot/.claude/skills/otmeiwa-emurator
```

- [ ] **Step 3: Commit**

```bash
git add -u
git commit -m "chore: remove otmeiwa_emurator HTTP polling emulator and skill"
```

---

### Task 2: Remove emulator polling from index.html

**Files:**
- Modify: `web/index.html` lines 626–640 (the `_emuConnected` / `setInterval fetch` block)

Current code to remove (lines 626–640):
```javascript
// Emulator polling (otmeiwa_emurator.rb — skipped when real serial connected)
let _emuConnected = false;
setInterval(async () => {
  if (_port) return;
  try {
    const r = await fetch('http://localhost:9999/frame');
    if (!r.ok) return;
    const d = await r.text();
    if (!d) return;
    if (!_emuConnected && window.rubySerialOnConnect) { _emuConnected = true; window.rubySerialOnConnect(115200); }
    if (window.rubySerialOnReceive) window.rubySerialOnReceive(d + '\n');
  } catch (_) {
    if (_emuConnected) { _emuConnected = false; if (window.rubySerialOnDisconnect) window.rubySerialOnDisconnect(); }
  }
}, 50);
```

- [ ] **Step 1: Remove the emulator polling block from index.html**

In `web/index.html`, replace the block above (everything from `// Emulator polling` through the closing `}, 50);`) with nothing. The file should end with:

```javascript
// Initial placeholder draw
drawSynthGraph();
drawSensorHistory();

</script>
</body>
</html>
```

- [ ] **Step 2: Verify index.html ends cleanly**

```bash
tail -10 /Users/bash/dev/src/github.com/bash0C7/picoruby-ot/web/index.html
```

Expected: last JS line is `drawSensorHistory();`, then `</script>`, `</body>`, `</html>`.

---

### Task 3: Add Test Mode HTML section

**Files:**
- Modify: `web/index.html` — add new section between "Serial Monitor" and `</div>` closing `#app`

Insert the following HTML just before the closing `</div>` of `#app` (currently after `<!-- Serial Monitor -->` section, around line 169):

- [ ] **Step 1: Add Test Mode HTML section**

In `web/index.html`, find the Serial Monitor section closing tag:

```html
  <!-- Serial Monitor -->
  <div class="sec">
    <div class="t">Serial Monitor</div>
    <div id="mon"></div>
  </div>
</div>
```

Replace with:

```html
  <!-- Serial Monitor -->
  <div class="sec">
    <div class="t">Serial Monitor</div>
    <div id="mon"></div>
  </div>

  <!-- Test Mode -->
  <div class="sec">
    <div class="t">Test Mode (no hardware)</div>
    <div class="r2" style="margin-bottom:6px">
      <button id="bTCon" onclick="testConnect()">Test Connect</button>
      <button id="bTDis" onclick="testDisconnect()" disabled>Test Stop</button>
      <button id="bTLoop" onclick="testToggleLoop()" disabled>Loop</button>
      <button onclick="testSendOnce()" id="bTSend" disabled>Send Once</button>
    </div>
    <div class="row">
      <label>Dist mm</label>
      <input type="range" id="tD" min="20" max="900" value="450" oninput="this.nextElementSibling.textContent=this.value">
      <span class="v">450</span>
    </div>
    <div class="row">
      <label>AX</label>
      <input type="range" id="tAX" min="-1000" max="1000" value="0" oninput="this.nextElementSibling.textContent=this.value">
      <span class="v">0</span>
    </div>
    <div class="row">
      <label>AY</label>
      <input type="range" id="tAY" min="-1000" max="1000" value="0" oninput="this.nextElementSibling.textContent=this.value">
      <span class="v">0</span>
    </div>
    <div class="row">
      <label>AZ</label>
      <input type="range" id="tAZ" min="-1000" max="1000" value="0" oninput="this.nextElementSibling.textContent=this.value">
      <span class="v">0</span>
    </div>
  </div>
</div>
```

---

### Task 4: Add Test Mode JS

**Files:**
- Modify: `web/index.html` — add JS functions before `</script>`

- [ ] **Step 1: Add test mode JS just before `</script>`**

In `web/index.html`, find:

```javascript
// Initial placeholder draw
drawSynthGraph();
drawSensorHistory();

</script>
```

Replace with:

```javascript
// Initial placeholder draw
drawSynthGraph();
drawSensorHistory();

// ============================================================
// Test Mode (inline sensor emulation, no hardware needed)
// ============================================================
let _testLoop = null;

function _testFrame() {
  const d  = document.getElementById('tD').value;
  const ax = document.getElementById('tAX').value;
  const ay = document.getElementById('tAY').value;
  const az = document.getElementById('tAZ').value;
  return `<D:${d},AX:${ax},AY:${ay},AZ:${az}>\n`;
}

function testConnect() {
  if (_port) return; // real serial takes priority
  if (window.rubySerialOnConnect) window.rubySerialOnConnect(115200);
  document.getElementById('bTCon').disabled  = true;
  document.getElementById('bTDis').disabled  = false;
  document.getElementById('bTLoop').disabled = false;
  document.getElementById('bTSend').disabled = false;
}

function testDisconnect() {
  if (_testLoop) { clearInterval(_testLoop); _testLoop = null; }
  document.getElementById('bTLoop').textContent = 'Loop';
  document.getElementById('bTCon').disabled  = false;
  document.getElementById('bTDis').disabled  = true;
  document.getElementById('bTLoop').disabled = true;
  document.getElementById('bTSend').disabled = true;
  if (window.rubySerialOnDisconnect) window.rubySerialOnDisconnect();
}

function testSendOnce() {
  if (window.rubySerialOnReceive) window.rubySerialOnReceive(_testFrame());
}

function testToggleLoop() {
  const btn = document.getElementById('bTLoop');
  if (_testLoop) {
    clearInterval(_testLoop);
    _testLoop = null;
    btn.textContent = 'Loop';
  } else {
    _testLoop = setInterval(() => {
      if (window.rubySerialOnReceive) window.rubySerialOnReceive(_testFrame());
    }, 50);
    btn.textContent = 'Stop Loop';
  }
}

</script>
```

- [ ] **Step 2: Verify in Chrome**

1. Open `http://localhost:8000/index.html?v=tm1` in Chrome
2. Wait for `[Ruby] picoruby-ot synth ready!` in console (~10–15s)
3. Click **Init Audio** → status: `running`
4. Click **Test Connect** → serial status: `connected at 115200bps`
5. Move D slider → Sensor Monitor updates (D, Note, Freq)
6. Click **Send Once** → single update
7. Click **Loop** → continuous updates (oscilloscope animates)
8. Click **Stop Loop** → updates stop
9. Click **Test Stop** → serial status: `disconnected`

- [ ] **Step 3: Commit**

```bash
git add web/index.html
git commit -m "feat: add inline test mode to index.html, remove emulator polling"
```

---

## Self-Review

**Spec coverage:**
- ✅ emulator approach removed (Tasks 1, 2)
- ✅ sliders for D/AX/AY/AZ in index.html (Task 3)
- ✅ data flow identical to real hardware (`rubySerialOnReceive`) (Task 4)
- ✅ real serial takes priority (`if (_port) return`) (Task 4)
- ✅ `rubySerialOnConnect` / `rubySerialOnDisconnect` called to maintain status display (Task 4)

**No placeholders:** All code is complete.

**Type consistency:** `_testFrame()` → returns string in format `<D:NNN,AX:NNN,AY:NNN,AZ:NNN>\n` — matches what `serial.rb` parser expects.
