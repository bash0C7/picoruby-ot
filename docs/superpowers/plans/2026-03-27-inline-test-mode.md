# Inline Test Mode Implementation Plan

**Goal:** Replace the external emulator (HTTP polling) with inline test controls directly in index.html so sound can be tested without hardware or extra processes.

**Architecture:** Add a "Test Mode" section to index.html that builds `<D:NNN,AX:NNN,AY:NNN,AZ:NNN>\n` frames from sliders and injects them into `rubySerialOnReceive()` — the exact same path as real Web Serial data. The emulator files and skill are deleted.

**Status: ✅ COMPLETE** (commits f70d872–c17a045)

---

## Self-Review

**Spec coverage:**
- ✅ emulator approach removed (Tasks 1, 2)
- ✅ sliders for D/AX/AY/AZ in index.html (Task 3)
- ✅ data flow identical to real hardware (`rubySerialOnReceive`) (Task 4)
- ✅ real serial takes priority (`if (_port) return`) (Task 4)
- ✅ `rubySerialOnConnect` / `rubySerialOnDisconnect` called to maintain status display (Task 4)
