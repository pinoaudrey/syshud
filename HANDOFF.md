# SysHUD handoff

2026-08-06. v1 shipped, pushed to pinoaudrey/syshud (root commit 32bbac9).

## State

Working and verified on the MacBook Air (macOS 26, Swift 6.3):

- Menu bar item shows live "CPU% MEM" every 2s, verified visually (label
  ticked 18% to 21% across screenshots).
- 14/14 unit tests green across 4 consecutive runs.
- `swift run SysHUD --sample` prints real headless output (system + top 12
  processes).
- App bundles and launches via `./make-app.sh && open build/SysHUD.app`.

Not verified end to end: the kill button (needs a real click; the path is a
single `kill(2)` syscall) and the dropdown panel beyond the Quit button
(Audrey used Quit, so the panel opens and renders). Launch-at-login toggle
untested; it requires running from a real .app bundle.

## Machine state right now

- App running from `build/SysHUD.app` (not installed to /Applications).
- Launch at login: off.
- A position default is written on this Mac:
  `defaults write com.audreypino.syshud "NSStatusItem Preferred Position Item-0" -float 560`.
  Without it, new status items queue leftmost and get overflow-hidden behind
  Notion Calendar's 243pt item. Cmd-dragging the item overwrites this default.
- Trade-off left open: the bar's usable width right of the notch is 617pt.
  Full label + Agent HUD meters + remaining icons is ~632pt, so the Agent HUD
  meters are currently overflow-hidden. "Compact label" in the dropdown
  (CPU-only, ~40pt) frees enough to restore them. Audrey's call.

## Architecture

SwiftPM, two targets plus tests. Core is UI-free and unit-tested.

- `Sources/SysHUDCore/Sampler.swift`: all Darwin API access. Host CPU via
  `host_statistics(HOST_CPU_LOAD_INFO)` tick deltas; memory via
  `host_statistics64(HOST_VM_INFO64)` (internal - purgeable + wired +
  compressed, matches Activity Monitor); per-process via `proc_pid_rusage`
  (`ri_user_time`/`ri_system_time` are mach time units, converted through
  `mach_timebase_info`; `ri_phys_footprint` matches Activity Monitor's
  Memory column). Stateful deltas: first sample() reports 0% CPU.
- `Sources/SysHUDCore/{CPUMath,ByteFormat,Models}.swift`: pure logic, tested.
- `Sources/SysHUD/Entry.swift`: @main enum dispatches `--sample` CLI vs app.
- `Sources/SysHUD/Monitor.swift`: view model, 2s timer, sampling on a serial
  queue, kill action (SIGTERM, option-click SIGKILL).
- `Sources/SysHUD/HUDView.swift`: dropdown panel.
- `make-app.sh`: release build, .app bundle, ad-hoc codesign.

## Verify gate

`swift test` (14 tests), `swift run SysHUD --sample`, `./make-app.sh` and a
visual check of the menu bar. No lint config in this repo.

## Gotchas learned building this (do not relearn)

- A SwiftUI `Label` inside `MenuBarExtra` renders icon-only, silently
  dropping the text. Use an explicit `Image` + `Text` pair or plain `Text`.
- macOS hides status items right of the notch by truncating at the first
  item that doesn't fit; everything queued behind it hides too, even if
  narrower. Queue position beats item width. Newest-launched apps queue
  leftmost (worst position).
- On macOS 26, third-party status items render as Control-Center-owned
  windows (layer 25, `kCGWindowName` = owning bundle id). CGWindowList is
  the way to inspect visibility (`onscreen` flag) without accessibility
  permission. `isVisible` on NSStatusItem lies (reports true when
  overflow-hidden).
- Notch boundary on this 1470pt Air measured at x≈855, so usable status
  width is ~617pt.
- Asserting live system counters in one short window is flaky (kernel tick
  lag under load). The sampler test burns CPU and retries up to 5 times.
- Executable targets aren't cleanly testable; that's why the core is a
  library target.

## Next steps (none blocking)

1. `cp -R build/SysHUD.app /Applications/` and enable launch at login.
2. Other Macs: clone, `./make-app.sh` (ad-hoc signed, right-click Open on
   first launch). Decide whether a small brew tap is worth it.
3. Possible v2: auto-compact label when overflow is detected (CGWindowList
   self-check), per-core breakdown, network/disk meters.
