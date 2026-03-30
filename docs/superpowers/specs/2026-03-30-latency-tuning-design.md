# Latency Tuning Design — picoruby-ot Web Synth

Date: 2026-03-30

## Problem

The synth felt sluggish (~13fps effective rate, ~75ms latency) because:

1. `otmeiwa.rb` main loop had `sleep_ms(50)` stacked on top of VL53L0X measurement time (~20-25ms) → actual frame interval ~70-75ms
2. Glide TC (40ms) was tuned for 50ms frame interval, now needs adjustment

## Root Cause Analysis

Profiling results (browser side):
- `on_receive` avg: 0.67ms, p95: 1.4ms, max: 1.8ms → Ruby processing is negligible
- The bottleneck was entirely in the PicoRuby loop timing

Pipeline before fix:
```
VL53L0X measure (~20-25ms) + sleep_ms(50) = ~70ms = ~13fps
```

Pipeline after fix:
```
VL53L0X measure (~20-25ms) only = ~25ms = ~40fps
```

## Design

### PicoRuby side (otmeiwa.rb)

Remove `sleep_ms(50)` from main loop. VL53L0X's hardware measurement cycle is the natural pacemaker — no artificial delay needed.

```ruby
loop do
  IRQ.process
  instrument.update       # VL53L0X blocks ~20-25ms (chip timing)
  instrument.send_frame
  led_viz.update(...)
  led_viz.show
  # no sleep — VL53L0X is the clock
end
```

### Web side (main.rb + index.html)

Glide TC scaled to new frame period. Target ratio TC/frame ≈ 0.8 (same as before) for smooth portamento.

| Parameter | Before | After |
|-----------|--------|-------|
| Frame period | ~50ms | ~25ms |
| Glide TC | 40ms | 20ms |
| TC/frame ratio | 0.80 | 0.80 |

`@glide_sec = 0.020` — portamento quality preserved.

### Portamento invariant

TC/frame ≈ 0.8 ensures exponential curves from consecutive frames overlap, producing smooth violin-like pitch glide. This ratio is maintained across the change.

## Files Changed

- `src_components/R2P2-ESP32/storage/home/otmeiwa.rb`: remove `sleep_ms(50)`
- `web/src/ruby/main.rb`: `@glide_sec = 0.040` → `0.020`
- `web/index.html`: Glide slider default 40ms → 20ms

## Additional Optimizations (same session)

- Canvas animation: 60fps → 10fps (setTimeout 100ms) — reduces WASM heap pressure
- Canvas drawing moved to JS helpers — eliminated 120K JS::Object/sec WASM allocations
- WASM memory monitor: switched from `performance.memory` (JS heap) to `rubyVM.instance.exports.memory` (actual WASM heap)
