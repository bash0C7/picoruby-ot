---
name: otmeiwa-emurator
description: Start and operate the otmeiwa hardware emulator (Ruby IRB CLI). Use this skill whenever you need to test the web synthesizer without physical ATOM Matrix hardware — it starts the HTTP frame server, connects index.html automatically, and provides emit/loop_emit/sweep control. Trigger on "emulator", "エミュレーター", "hardware not available", "test without device", or before running web-synth-test without real hardware.
user-invocable: true
---

# otmeiwa_emurator — Hardware Emulator for Web Synth

`otmeiwa_emurator.rb` は ATOM Matrix (otmeiwa.rb) のエミュレーター。
HTTP サーバー (port 9999) でフレームを配信し、`index.html` が自動接続する。

---

## Quick Start

### Step 1: emulator を起動

```bash
cd /Users/bash/dev/src/github.com/bash0C7/picoruby-ot
ruby web/otmeiwa_emurator.rb
```

起動すると IRB コンソールが開く:

```
==================================================
Emulator ready: http://localhost:9999/frame
index.html を開くと自動接続します
==================================================

Methods:
  emit(d: 450, ax: 0, ay: 0, az: 0)       # 1フレーム送信
  loop_emit(d: 450, ax: 0, ay: 0, az: 0)  # 送り続ける (Ctrl+C で停止)
  sweep(:d, 20, 900)                        # パラメータをスイープ
```

### Step 2: web server を確認・起動

```bash
rake server:status
# 止まっていれば:
rake server:start
```

### Step 3: Chrome で index.html を開く

```
http://localhost:8000/index.html
```

ruby.wasm が起動すると **自動で** `connected at 115200bps` と表示される（10〜15秒待つ）。

### Step 4: Init Audio をクリック

Chrome の "Init Audio" ボタンをクリック → `audio: running` になる。

---

## IRB コマンドリファレンス

### `emit` — 1フレーム送信

```ruby
emit(d: 450, ax: 0, ay: 0, az: 0)
```

| パラメータ | 範囲 | 説明 |
|-----------|------|------|
| `d`  | 20〜900 | 距離 (mm)。低い=低音、高い=高音 |
| `ax` | -1000〜1000 | X軸加速度 (milliG) |
| `ay` | -1000〜1000 | Y軸加速度 (milliG) |
| `az` | -1000〜1000 | Z軸加速度 (milliG) |

距離→音程マッピング (ペンタトニック, デフォルト):
- d=20 → C2 (65Hz)
- d=450 → C4 (261Hz)
- d=900 → C6 (1047Hz)

### `loop_emit` — 連続送信

```ruby
loop_emit(d: 450, ax: 100, ay: 0, az: 0)
# Ctrl+C で停止
```

停止後は `emit` や `loop_emit` を再度呼べる。

### `sweep` — パラメータスイープ

```ruby
sweep(:d, 20, 900)              # 距離を20→900→20 と繰り返す
sweep(:d, 200, 600, step: 10)   # ステップ細かく
sweep(:ax, -500, 500)           # FM depth をスイープ
sweep(:d, 100, 800, ax: 200)    # 距離スイープ + FM固定
# Ctrl+C で停止
```

---

## 動作確認チェックリスト

emulator を起動したら以下を確認:

1. `emit(d: 450)` → Chrome の `D: 450mm`, `Note: C4`, `261Hz` が表示される ✅
2. `sweep(:d, 20, 900)` → 音程がゆっくり上下する ✅
3. `sweep(:ax, -500, 500, d: 450)` → FM depth が変化する ✅
4. emulator を Ctrl+D で終了 → Chrome の serial status が `disconnected` になる ✅

---

## 仕組み

```
otmeiwa_emurator.rb (Ruby IRB)
  │  emit() が $current_frame を更新
  │
  ▼
WEBrick HTTP Server (port 9999)
  GET /frame → "<D:450,AX:0,AY:0,AZ:0>"
  │
  ▼ (50ms ポーリング)
index.html (JavaScript)
  → rubySerialOnReceive("<D:450,...>\n")
  │
  ▼
main.rb (ruby.wasm)
  → SensorMapper → updateSensorParams(freq, fm_depth, active)
  │
  ▼
Web Audio API → 音出力
```

## 注意事項

- 実機 (Web Serial) が接続中の場合、emulator polling は自動スキップされる (`_port` 変数で判定)
- emulator は `ruby web/otmeiwa_emurator.rb` でフォアグラウンド起動が必要 (IRB が TTY を要求するため)
- port 9999 が使用中の場合は既存プロセスを kill してから起動: `lsof -ti:9999 | xargs kill -9`
