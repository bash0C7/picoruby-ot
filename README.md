# picoruby-ot: びことん

明和電機のオタマトーンにインスパイアされたソフトウェア楽器。  
A software musical instrument inspired by Maywa Denki's Otamatone.

距離センサーで音程を操作。スティックを振ってFM合成エフェクト。  
Distance sensor controls pitch. Shake the stick for FM synthesis effects.

M5 ATOM Matrix (ESP32) + PicoRuby + Chrome Web Audio で製作。  
Built with M5 ATOM Matrix (ESP32) + PicoRuby + Chrome Web Audio.

## ハードウェア / Hardware

| コンポーネント / Component | 購入先 / Link |
|---------------------------|--------------|
| M5 ATOM Matrix (ESP32-PICO-D4) | [スイッチサイエンス](https://ssci.to/6260) |
| Unit ToF (VL53L0X 距離センサー / laser distance sensor) | [スイッチサイエンス](https://ssci.to/5219) |
| LED スティック (10 RGB LEDs) | [スイッチサイエンス](https://ssci.to/5953) |
| アクリルパイプ 直径4mm × 1m × 2本 / Acrylic pipe, 4mm dia. × 1m, ×2 | (ホームセンター等) |
| USB ケーブル / USB cable | — |
| PC (Chrome が動けばOK) / PC running Chrome | (動作確認: MacBook Air M3 13-inch 2024) |

## 仕組み / How it works

1. `otmeiwa.rb` を R2P2-ESP32 経由で ATOM Matrix にフラッシュ  
   Flash `otmeiwa.rb` to ATOM Matrix via R2P2-ESP32
2. Chrome で `web/index.html` を開く (`cd web && ruby -run -ehttpd . -p8000`)  
   Open `web/index.html` in Chrome (serve with `cd web && ruby -run -ehttpd . -p8000`)
3. Connect ボタンを押して ATOM Matrix のシリアルポートを選択 (115200bps)  
   Click Connect, select the ATOM Matrix serial port (115200bps)
4. センサーを手に持って動かすと距離で音程が変化  
   Hold the sensor and move your hand — distance controls pitch

## アーキテクチャ / Architecture

```
ATOM Matrix (otmeiwa.rb)
  VL53L0X 距離センサー → USB Serial 115200bps
    ↓ <D:NNNN,AX:NNNN,AY:NNNN,AZ:NNNN>
Chrome (web/index.html)
  ruby.wasm → SensorMapper → FM Synthesizer (Web Audio API)
```

## アプリ一覧 / Apps

| ファイル / File | 説明 / Description |
|---------------|-------------------|
| `otmeiwa.rb` | 距離＋加速度センサー → USB Serial → Chrome FM シンセ / Distance + accel sensor → USB Serial → Chrome FM synth |
| `otma.rb` | 自動ドラムマシン (MIDI 出力、16ステップシーケンサー、WS2812 LED) / Auto drum machine (MIDI out, 16-step sequencer, WS2812 LED) |
| `otpwm.rb` | 距離センサー → PWM スピーカー (スタンドアロン) / Distance sensor → PWM speaker (standalone) |
| `otdr.rb` | MIDI ソフトスルー gateway (Power Drums、ボタン/クラッシュ LED フラッシュ) / MIDI soft-through gateway (Power Drums, button/crash LED flash) |

### otdr.rb — MIDI ソフトスルー / MIDI Soft-Through Gateway

受信した MIDI ドラムノートをそのまま転送 (ソフトスルー)。自動演奏なし。  
Receives MIDI drum notes and forwards them unchanged (soft-through). No auto-play.

ボタン押下で全 LED フラッシュ。クラッシュシンバル (note 49) でも同様。  
Button press flashes all LEDs. Crash cymbal (note 49) also triggers flash.

受信 MIDI ノートグループに応じて LED 色が変化。GM2 Power Kit (Program Change 16) で初期化。  
LED color reacts to incoming MIDI note groups. Initialized with GM2 Power Kit (Program Change 16).

ビルド: `rake build APP=otdr && rake flash`  
Build: `rake build APP=otdr && rake flash`

## 自分で作る / Reproducing This Instrument

上記のコンポーネントはすべて市販品。このリポジトリとハードウェアがあれば展示と全く同じものが作れます。  
All components listed above are commercially available. With this repository and the hardware, you can build the exact same instrument shown at the exhibition.

### 1. ビルド環境のセットアップ / Set up the build environment

[mruby girls ESP32 ガイド](https://mrubygirls.github.io/guides/esp32/) に従って ESP-IDF ツールチェーンと R2P2-ESP32 ファームウェアをインストール。  
Follow the [mruby girls ESP32 guide](https://mrubygirls.github.io/guides/esp32/) to install the ESP-IDF toolchain and R2P2-ESP32 firmware.

### 2. ビルド＆フラッシュ / Build and flash

詳細は `src_components/R2P2-ESP32/CLAUDE.md` を参照。  
See `src_components/R2P2-ESP32/CLAUDE.md` for build instructions.
