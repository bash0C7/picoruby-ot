# TODO: Production Polish

## otmeiwa.rb (Sensor Output)

- [ ] **Calibration on boot**: キャリブレーション未実施時に重力ベクトル(~1000 milliG)がそのまま出力される問題 — 起動時自動キャリブレーション or 起動ガイダンス表示
- [ ] **Distance noise filtering**: D値が20mmにジャンプする外れ値除去（移動平均 or 中央値フィルタ）
- [ ] **Frame rate stability**: ~20fps を安定させる（sleep調整）

## web/ (Chrome Synth)

- [ ] **Pitch mapping**: 距離→音程の対数スケール調整（現状まだ「音程になっていない」）
  - 距離レンジ(20〜900mm)をMIDIノート範囲にマッピング
  - log2スケールで等テンポ音程感を出す
- [ ] **FM depth response**: 加速度→FM depth の感度チューニング（accel_scale調整）
- [ ] **Drone/trigger mode**: 距離閾値以下で音を止める（センサー範囲外=無音）
- [ ] **Smooth glide**: 音程変化のglide time設定（急激な跳びを抑制）
- [ ] **Visual feedback**: Canvas oscilloscope / level meter の動作確認

## DevOps

- [ ] **Web Serial auto-reconnect**: 切断時の自動再接続
- [ ] **Error display**: パースエラー時のUI表示（現状サイレント失敗）
