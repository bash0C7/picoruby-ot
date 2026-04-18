# otmeiwa_emurator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `web/otmeiwa_emurator.html` — a browser page that emulates ATOM Matrix sensor output via Web Serial write, connected to index.html via a Ruby PTY bridge in server.rb.

**Architecture:** server.rb creates two PTY slave devices on startup and bridges them via a background thread. otmeiwa_emurator.html uses ruby.wasm to generate sensor frames from sliders and writes them to slave1 via Web Serial. index.html connects to slave2 via Web Serial and receives frames as if from real hardware.

**Tech Stack:** ruby.wasm (CRuby 4.0-wasm-wasi 2.8.1), Web Serial API (Chrome), Ruby PTY stdlib, WEBrick

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `web/server.rb` | Modify | Add PTY pair creation + bridge thread |
| `web/src/ruby/emulator/frame_generator.rb` | Create | Build `<D:N,AX:N,AY:N,AZ:N>\n` string |
| `web/src/ruby/emulator/emulator_app.rb` | Create | Read sliders → generate frames → write serial |
| `web/otmeiwa_emurator.html` | Create | HTML + CSS + JS glue + ruby.wasm loader |

---

## Task 1: PTY Bridge in server.rb

**Files:**
- Modify: `web/server.rb`

- [ ] **Step 1: Verify PTY works on this machine**

```bash
ruby -e "require 'pty'; m,s = PTY.open; puts s.path; m.close; s.close"
```

Expected: prints a path like `/dev/ttys005` with no errors.

- [ ] **Step 2: Write inline test for PTY round-trip**

```bash
ruby -e "
require 'pty'
m1, s1 = PTY.open
m2, s2 = PTY.open
s1.raw!
s2.raw!
t = Thread.new do
  loop do
    begin
      data = m1.read_nonblock(256)
      m2.write(data)
    rescue IO::WaitReadable
      IO.select([m1], nil, nil, 0.01)
    rescue
      break
    end
  end
end
s1.write('<D:100,AX:0,AY:0,AZ:0>\n')
sleep 0.1
result = s2.read_nonblock(256) rescue ''
t.kill
[m1,s1,m2,s2].each { |f| f.close rescue nil }
raise 'FAIL: got empty result' if result.empty?
puts 'PASS: ' + result.strip
"
```

Expected output: `PASS: <D:100,AX:0,AY:0,AZ:0>`

- [ ] **Step 3: Add PTY bridge to server.rb**

Replace the content of `web/server.rb` with:

```ruby
#!/usr/bin/env ruby
# WEBrick開発サーバー
# 使用法: ruby web/server.rb [port] [document_root]

require 'webrick'
require 'pty'

port = (ARGV[0] || 8000).to_i
root = File.expand_path(ARGV[1] || File.dirname(__FILE__))

# 仮想シリアルペア作成
$pty_master1, pty_slave1 = PTY.open
$pty_master2, pty_slave2 = PTY.open
pty_slave1.raw!
pty_slave2.raw!

puts "=" * 50
puts "Emulator port: #{pty_slave1.path}"
puts "Synth port:    #{pty_slave2.path}"
puts "=" * 50

# エミュレーター → シンセ 中継スレッド
Thread.new do
  loop do
    begin
      data = $pty_master1.read_nonblock(256)
      $pty_master2.write(data)
    rescue IO::WaitReadable
      IO.select([$pty_master1], nil, nil, 0.01)
    rescue
      break
    end
  end
end

# wasmファイルのMIMEタイプ登録
WEBrick::HTTPUtils::DefaultMimeTypes['wasm'] = 'application/wasm'
WEBrick::HTTPUtils::DefaultMimeTypes['mjs']  = 'text/javascript'

server = WEBrick::HTTPServer.new(
  Port: port,
  DocumentRoot: root,
  Logger: WEBrick::Log.new($stdout, WEBrick::Log::INFO),
  AccessLog: [[
    $stdout,
    WEBrick::AccessLog::COMBINED_LOG_FORMAT
  ]]
)

trap('INT')  { server.shutdown }
trap('TERM') { server.shutdown }

puts "WEBrick server starting on http://localhost:#{port}/"
puts "Document root: #{root}"
server.start
```

- [ ] **Step 4: Run server and verify PTY paths are printed**

```bash
cd /Users/bash/dev/src/github.com/bash0C7/picoruby-ot
ruby web/server.rb &
sleep 1
kill %1 2>/dev/null; true
```

Expected: output includes `Emulator port: /dev/ttys0XX` and `Synth port: /dev/ttys0YY`.

- [ ] **Step 5: Commit**

```bash
git add web/server.rb
git commit -m "feat: add PTY virtual serial bridge to server.rb"
```

---

## Task 2: FrameGenerator Module

**Files:**
- Create: `web/src/ruby/emulator/frame_generator.rb`

- [ ] **Step 1: Verify frame format spec**

The expected format: `<D:100,AX:50,AY:-30,AZ:0>\n`

Run the spec inline:

```bash
ruby -e "
module FrameGenerator
  def self.build(d, ax, ay, az)
    \"<D:\#{d},AX:\#{ax},AY:\#{ay},AZ:\#{az}>\n\"
  end
end

tests = [
  [FrameGenerator.build(100, 50, -30, 0),   \"<D:100,AX:50,AY:-30,AZ:0>\n\"],
  [FrameGenerator.build(20,  0,   0,  0),   \"<D:20,AX:0,AY:0,AZ:0>\n\"],
  [FrameGenerator.build(900, 1000, -1000, 500), \"<D:900,AX:1000,AY:-1000,AZ:500>\n\"],
]
tests.each_with_index do |(got, expected), i|
  raise \"FAIL test \#{i}: got \#{got.inspect}, expected \#{expected.inspect}\" unless got == expected
end
puts 'PASS: all frame format tests'
"
```

Expected: `PASS: all frame format tests`

- [ ] **Step 2: Create frame_generator.rb**

Create `web/src/ruby/emulator/frame_generator.rb`:

```ruby
module FrameGenerator
  def self.build(d, ax, ay, az)
    "<D:#{d},AX:#{ax},AY:#{ay},AZ:#{az}>\n"
  end
end
```

- [ ] **Step 3: Commit**

```bash
git add web/src/ruby/emulator/frame_generator.rb
git commit -m "feat: add FrameGenerator module for otmeiwa_emurator"
```

---

## Task 3: EmulatorApp Class

**Files:**
- Create: `web/src/ruby/emulator/emulator_app.rb`

- [ ] **Step 1: Create emulator_app.rb**

Create `web/src/ruby/emulator/emulator_app.rb`:

```ruby
require 'js'

class EmulatorApp
  def initialize
    @connected = false
  end

  def register_callbacks
    app = self
    JS.global[:rubyTick] = lambda do
      app.tick
    end
    JS.global[:rubyEmulatorOnConnect] = lambda do
      app.on_connect
    end
    JS.global[:rubyEmulatorOnDisconnect] = lambda do
      app.on_disconnect
    end
  end

  def on_connect
    @connected = true
  end

  def on_disconnect
    @connected = false
  end

  def tick
    return unless @connected
    d  = JS.global[:emD].to_i
    ax = JS.global[:emAX].to_i
    ay = JS.global[:emAY].to_i
    az = JS.global[:emAZ].to_i
    frame = FrameGenerator.build(d, ax, ay, az)
    JS.global.serialWrite(frame)
    JS.global.updateFrameMonitor(frame.strip)
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add web/src/ruby/emulator/emulator_app.rb
git commit -m "feat: add EmulatorApp class for otmeiwa_emurator"
```

---

## Task 4: otmeiwa_emurator.html

**Files:**
- Create: `web/otmeiwa_emurator.html`

- [ ] **Step 1: Create otmeiwa_emurator.html**

Create `web/otmeiwa_emurator.html`:

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>picoruby-ot Emurator (otmeiwa)</title>
  <style>
    *{box-sizing:border-box;margin:0;padding:0}
    body{background:#0e0e0e;color:#ccc;font-family:monospace;font-size:12px;padding:10px}
    h1{color:#0f0;font-size:16px;margin-bottom:10px;border-bottom:1px solid #2a2a2a;padding-bottom:6px}
    #app{max-width:620px;margin:0 auto}
    .sec{background:#141414;border:1px solid #2a2a2a;border-radius:4px;padding:8px 10px;margin-bottom:8px}
    .t{color:#0cc;font-size:10px;font-weight:bold;margin-bottom:6px;text-transform:uppercase;letter-spacing:1px}
    .row{display:flex;align-items:center;margin-bottom:4px;gap:6px}
    .row label{width:100px;color:#666;flex-shrink:0;font-size:11px}
    .row input[type=range]{flex:1;accent-color:#0f0;height:14px}
    .row .v{width:44px;text-align:right;color:#888;font-size:11px}
    .r2{display:flex;gap:6px;align-items:center;flex-wrap:wrap;margin-bottom:4px}
    button{background:#1a1a1a;border:1px solid #444;color:#aaa;cursor:pointer;padding:3px 9px;font-family:monospace;font-size:11px;border-radius:3px}
    button:hover{border-color:#0f0;color:#0f0}
    .st{color:#0f0;font-size:11px;padding:2px 6px;background:#0a150a;border:1px solid #1a3a1a;border-radius:3px}
    .st.e{color:#f44;background:#150a0a;border-color:#3a1a1a}
    select{background:#1a1a1a;color:#aaa;border:1px solid #444;font-family:monospace;font-size:11px;padding:2px 4px;border-radius:3px}
    #mon{background:#080808;border:1px solid #1a1a1a;border-radius:3px;padding:5px;font-size:10px;color:#0a0;word-break:break-all}
  </style>
</head>
<body>
<div id="app">
  <h1>picoruby-ot Emurator (otmeiwa)</h1>

  <!-- Serial -->
  <div class="sec">
    <div class="t">Serial</div>
    <div class="r2">
      <button id="bCon" onclick="serialConnect()">Connect</button>
      <button id="bDis" onclick="serialDisconnect()" disabled>Disconnect</button>
      <select id="baud"><option value="115200" selected>115200</option></select>
      <span class="st e" id="sst">disconnected</span>
    </div>
  </div>

  <!-- Sensor Controls -->
  <div class="sec">
    <div class="t">Sensor Controls</div>
    <div class="row">
      <label>Distance mm</label>
      <input type="range" id="sD" min="20" max="900" value="450"
             oninput="window.emD=+this.value;this.nextElementSibling.textContent=this.value">
      <span class="v">450</span>
    </div>
    <div class="row">
      <label>AX</label>
      <input type="range" id="sAX" min="-1000" max="1000" value="0"
             oninput="window.emAX=+this.value;this.nextElementSibling.textContent=this.value">
      <span class="v">0</span>
    </div>
    <div class="row">
      <label>AY</label>
      <input type="range" id="sAY" min="-1000" max="1000" value="0"
             oninput="window.emAY=+this.value;this.nextElementSibling.textContent=this.value">
      <span class="v">0</span>
    </div>
    <div class="row">
      <label>AZ</label>
      <input type="range" id="sAZ" min="-1000" max="1000" value="0"
             oninput="window.emAZ=+this.value;this.nextElementSibling.textContent=this.value">
      <span class="v">0</span>
    </div>
  </div>

  <!-- Frame Monitor -->
  <div class="sec">
    <div class="t">Frame Monitor</div>
    <div id="mon">--</div>
  </div>
</div>

<script>
window.emD  = 450;
window.emAX = 0;
window.emAY = 0;
window.emAZ = 0;

let _port, _writer;

async function serialConnect() {
  try {
    _port = await navigator.serial.requestPort();
    const baud = +document.getElementById('baud').value;
    await _port.open({ baudRate: baud });
    _writer = _port.writable.getWriter();
    document.getElementById('sst').textContent = 'connected at ' + baud + 'bps';
    document.getElementById('sst').className = 'st';
    document.getElementById('bCon').disabled = true;
    document.getElementById('bDis').disabled = false;
    if (window.rubyEmulatorOnConnect) window.rubyEmulatorOnConnect();
  } catch (e) {
    document.getElementById('sst').textContent = e.message;
    document.getElementById('sst').className = 'st e';
  }
}

async function serialDisconnect() {
  if (window.rubyEmulatorOnDisconnect) window.rubyEmulatorOnDisconnect();
  if (_writer) { try { await _writer.close(); } catch (_) {} _writer = null; }
  if (_port)   { try { await _port.close();  } catch (_) {} _port   = null; }
  document.getElementById('sst').textContent = 'disconnected';
  document.getElementById('sst').className = 'st e';
  document.getElementById('bCon').disabled = false;
  document.getElementById('bDis').disabled = true;
}

async function serialWrite(data) {
  if (!_writer) return;
  try { await _writer.write(new TextEncoder().encode(data)); }
  catch (e) { console.error('[serialWrite]', e); }
}

function updateFrameMonitor(text) {
  document.getElementById('mon').textContent = text;
}

setInterval(() => { if (window.rubyTick) window.rubyTick(); }, 50);
</script>

<script src="https://cdn.jsdelivr.net/npm/@ruby/4.0-wasm-wasi@2.8.1/dist/browser.script.iife.js"></script>
<script type="text/ruby" src="src/ruby/emulator/frame_generator.rb"></script>
<script type="text/ruby" src="src/ruby/emulator/emulator_app.rb"></script>
<script type="text/ruby">
require 'js'

begin
  $app = EmulatorApp.new
  $app.register_callbacks
  JS.global[:console].log("[Ruby] otmeiwa_emurator ready")
rescue => e
  JS.global[:console].error("[Ruby] Fatal: #{e.message}")
end
</script>
</body>
</html>
```

- [ ] **Step 2: Commit**

```bash
git add web/otmeiwa_emurator.html
git commit -m "feat: add otmeiwa_emurator.html with ruby.wasm sensor emulator"
```

---

## Task 5: Integration Verification

**Manual test — no automated test possible for browser/serial.**

- [ ] **Step 1: Start the web server**

```bash
cd /Users/bash/dev/src/github.com/bash0C7/picoruby-ot
ruby web/server.rb
```

Expected output:
```
==================================================
Emulator port: /dev/ttysXXX
Synth port:    /dev/ttysYYY
==================================================
WEBrick server starting on http://localhost:8000/
```

Note the two device paths.

- [ ] **Step 2: Open otmeiwa_emurator.html in Chrome**

Open `http://localhost:8000/otmeiwa_emurator.html`

Open Chrome DevTools → Console tab. Expected: `[Ruby] otmeiwa_emurator ready`

- [ ] **Step 3: Connect emulator to Emulator port**

Click **Connect** → select the device matching `Emulator port` path from Step 1.

Expected: status badge turns green, shows `connected at 115200bps`.

Check Frame Monitor: shows `<D:450,AX:0,AY:0,AZ:0>` updating.

- [ ] **Step 4: Open index.html in a second Chrome tab**

Open `http://localhost:8000/index.html`

Click **Connect** → select the device matching `Synth port` path from Step 1.

Click **Init Audio**.

- [ ] **Step 5: Verify sound output**

Move the Distance mm slider in otmeiwa_emurator.html.

Expected: pitch changes in index.html synth. Oscilloscope canvas shows waveform.

Move AX/AY/AZ sliders: FM depth changes (timbre variation).

- [ ] **Step 6: Final commit if any fixes were needed**

```bash
git add -p
git commit -m "fix: <describe any corrections>"
```
