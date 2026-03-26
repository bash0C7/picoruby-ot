# TODO: Production Polish

---

## ★ web/ (Chrome Synth) ← 最大優先：楽器としての完成度はここ

### 音程・音楽性
- [ ] **MIDI note quantization**: 距離→MIDIノート番号変換（semitone snap）
  - 距離レンジ(20〜900mm) → MIDI note 36-84 (C2-C6, 4オクターブ)
  - log2スケールで等音程感を出す
  - スケール選択UI: クロマチック / ペンタトニック / メジャー / マイナー
- [ ] **Smooth glide**: 音程変化のglide time設定（theremin的な滑らかさ）
  - 現状 50ms time constant、もっと長くして滑らかに
- [ ] **Drone/trigger mode**: 距離閾値以下で無音（センサー範囲外=ミュート）

### シンセ音色・表現力
- [ ] **シンセプリセット**: ボタン1発で音色切り替え
  - "Clean" — FMなし、サイン波のみ
  - "FM Light" — 軽いFM変調
  - "FM Heavy" — 深いFM変調（現状に近い）
  - "Acid" — ノコギリ波 + フィルター
- [ ] **キャリア波形選択**: sine / square / sawtooth / triangle
- [ ] **FM depth 手動スライダー**: 加速度に加えて手動でも調整できるように
- [ ] **FM depth response**: 加速度→FM depth 感度チューニング（accel_scale調整）

### UI/UX
- [ ] **画面150%表示**: `body { zoom: 1.5 }` をCSSに追加
- [ ] **Visual feedback**: Canvas oscilloscope / level meter の動作確認・チューニング

---

## otmeiwa.rb (Sensor Output)

- [ ] **LED saturation**: calibrate直後はmag=0で彩度最小値(100/255)になり白っぽい — `saturation = (mag * 55 / 1500 + 200).clamp(200, 255)` で最小値200に引き上げ
- [ ] **Calibration on boot**: キャリブレーション未実施時に重力ベクトル(~1000 milliG)がそのまま出力される問題 — 起動時自動キャリブレーション or 起動ガイダンス表示
- [ ] **Distance noise filtering**: D値が20mmにジャンプする外れ値除去（移動平均 or 中央値フィルタ）
- [ ] **Frame rate stability**: ~20fps を安定させる（sleep調整）


## DevOps

- [ ] **Web Serial auto-reconnect**: 切断時の自動再接続
- [ ] **Error display**: パースエラー時のUI表示（現状サイレント失敗）
