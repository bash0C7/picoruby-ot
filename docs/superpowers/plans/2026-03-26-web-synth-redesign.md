# Web Synth Redesign Implementation Plan

**Goal:** Redesign the Chrome web synth into a cockpit-style Otamatone instrument with scale-snap glide, FM preset exploration, and simplified Ruby internals.

**Architecture:** 4 flat Ruby files (serial.rb, sensor_mapper.rb, preset_manager.rb, main.rb) + unchanged synth_patch/ DSL. JS is glue-only. UI is a 2-column always-visible cockpit with 150% zoom.

**Tasks 1–7: ✅ COMPLETE** (commits e3801fb–a0657d2, smoke test passed 8/8)
