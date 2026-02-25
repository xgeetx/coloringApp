# Spelling Fun Performance Remediation Plan

**Date:** February 25, 2026
**Scope:** `ColoringApp/SpellingView.swift`

## What Logs Were Available

I inspected local and remote project trees for runtime/perf logs (`.log`, `.trace`, `.xcresult`, Instruments exports, simulator logs).

Available artifacts were:
- `.git/logs/*` (git reflog metadata)
- planning docs
- source files

No runtime performance logs were present. This plan is based on static code-path analysis and known SwiftUI performance failure modes in the current implementation.

---

## Likely Root Causes of Slowness

1. High-frequency full-view invalidation from a single `@ObservedObject`
- `SpellingViewModel` drives the entire screen.
- Any `@Published` update can trigger broad body recomputation.
- This is most expensive while transcript text updates and stage tiles are active.

2. Expensive visual effects in frequently-updating paths
- Large shadows on moving letter tiles.
- Repeated transparent overlays and layered rounded-rectangle backgrounds.
- These increase GPU compositing cost and can drop FPS on older iPads.

3. Main-thread pressure from speech + UI updates
- Speech recognition callbacks update `transcript` continuously.
- State transitions and tile animation scheduling are all on the main actor.

4. O(n) tile lookup + array mutation pattern
- Tile updates use `firstIndex(where:)` repeatedly.
- As word length grows, drag/animation updates do more scanning and copying.

5. Potential duplicate/stacked animation work
- Letter launch uses delayed dispatch per tile and spring animations per item.
- Multiple rapid word submissions can queue overlapping animation work.

---

## Fix Plan (Priority Order)

## Phase 1: Add Measurement First (same day)

1. Add lightweight runtime telemetry to confirm bottlenecks
- Add `os_signpost` around:
  - speech callback processing
  - `startSpellingFromTranscript`
  - `animateLettersIn`
  - drag begin/end
  - shuffle
- Add frame-rate sampling (`CADisplayLink`) in debug builds for stage screen.

2. Establish baseline
- Record these metrics for 3 words: 4 letters, 8 letters, 12 letters.
- Capture:
  - median FPS
  - 1% low FPS
  - main-thread utilization
  - CPU/GPU from Instruments Time Profiler + Core Animation.

**Exit criteria:** We have measured top two hotspots with evidence.

---

## Phase 2: Low-Risk Rendering Optimizations (same day)

1. Reduce compositing cost on moving tiles
- Disable tile shadow during drag, or replace with tiny fixed shadow.
- Avoid dynamic shadow radius changes while dragging.

2. Flatten static backgrounds
- Replace translucent/material-like layers in hot screens with opaque fills.
- Keep visual style but remove unnecessary alpha blending.

3. Throttle nonessential transcript UI updates
- While listening, debounce transcript render updates (e.g., 8-10 Hz max).
- Keep raw transcript internal if needed, but avoid repainting every partial token.

**Expected impact:** 20-40% smoother drag on mid-range iPads.

---

## Phase 3: State Isolation and Data Model Optimization (next day)

1. Split view model responsibilities
- Create separate state objects:
  - `SpeechState`
  - `StageState`
- Keep transcript updates from invalidating stage views.

2. Optimize tile storage
- Store tile index map (`[UUID: Int]`) or use identifiable mutable structs with direct index access.
- Remove repeated `firstIndex(where:)` scans in hot paths.

3. Limit animation contention
- Cancel pending launch animations when a new word starts.
- Use a generation token to ignore stale delayed callbacks.

**Expected impact:** large reduction in main-thread churn and dropped frames during rapid interactions.

---

## Phase 4: Interaction-Specific Hardening (next day)

1. Gate rotation for toddlers and performance mode
- Add feature flag: `rotationEnabled`.
- Default OFF on low-performance devices or toddler mode.

2. Reduce simultaneous gesture complexity
- Keep drag primary; process rotation only after long-press/two-finger threshold.

3. Avoid haptic overuse
- Ensure drag haptic fires once per drag cycle only (already close; verify no duplicates).

**Expected impact:** lower gesture jitter and fewer event bursts.

---

## Validation Plan

1. Device matrix
- At least one older iPad + one newer iPad simulator/device.

2. Test scenarios
- Repeated 5-word sessions with drag, shuffle, and typed fallback.
- Rapid start/stop mic interactions.
- Long word (12+ letters) stress test.

3. Success thresholds
- Median FPS >= 50 during drag on stage.
- No visible stutter during letter launch sequence.
- No dropped interaction events on repeated drags.
- No crash or stuck state in 10-minute monkey test.

---

## Concrete First Implementation Batch

1. Add debug performance instrumentation (`os_signpost`, FPS sampler).
2. Remove dynamic tile shadow changes during drag.
3. Debounce transcript UI updates.
4. Add animation generation token to cancel stale delayed launches.
5. Re-profile and compare against baseline.

This batch should be implemented before any further visual redesign.
