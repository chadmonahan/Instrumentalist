# Dev handoff — pick-up notes

Working notes so a Claude Code session (or future-you) on another machine can
continue without the chat history. Start a session in the repo and say:
*"read docs/HANDOFF.md to catch up."*

Last updated: 2026-06-22 · at commit `4c9851d` on `main`.

## What this app is

"Hymns" (project name Instrumentalist) — a kiosk iPad/iOS hymn player for Sunday
services. Slots: Prelude / Opening / Memorial / Closing / Postlude, a number pad,
system-volume control, and a prelude countdown with auto-play so the prelude
finishes right as the service starts. Audio is mp3s fetched from Azure and cached
on disk. See [README.md](../README.md) for build setup.

## Recent work (this session)

All on `main`, pushed.

- **Countdown is daily + test mode** — `ServiceSchedule.nextStart` now targets the
  next 10:30 on *any* day (was Sunday-only), and a temporary `testMode` targets
  the next :00/:30 half-hour for quick testing. See
  [Config/ServiceSchedule.swift](../Instrumentalist/Config/ServiceSchedule.swift).
- **Go-time states** — once past the "start-by" moment the auto-play button and
  countdown hide; while the prelude actually plays (auto OR manual early press) we
  show the current medley hymn number like the other slots, with progress.
  Pausing/stopping returns to the countdown (time left) or the late-start chooser.
- **Late-start chooser** — past start-by, two buttons: "Play full" (runs past the
  service) or "End on time" (trims the front of the medley so it still finishes at
  the service start). Trim is computed live from now; works mid-medley (drops whole
  leading hymns if needed). See `AudioController.play(skipping:)` and
  `AppModel.playToFinishOnTime()`.
- **Now-playing medley number** — `AudioController.currentItemIndex` tracks the
  sounding item; `AppModel.preludePlayingNumber` maps it to the hymn number.
- **UI polish** — non-active slot buttons dimmed to 0.65 opacity so the active
  green stands out ([Views/SlotButton.swift](../Instrumentalist/Views/SlotButton.swift)).
- **Startup responsiveness hardening** — idempotent screen-wake (no per-touch UIKit
  churn), replaced a whole-screen zero-distance `DragGesture` with a non-intrusive
  `TapGesture` (was a likely first-launch unresponsiveness cause), and deferred
  audio-session activation off the launch path. Files: `State/AppModel.swift`,
  `Views/ContentView.swift`, `Services/AudioController.swift`.
- **Repo is now clone-and-open** — the XcodeGen-generated `.xcodeproj` is committed
  (shared files only), plus `README.md` and `Local.xcconfig.example`.

## ⚠️ Open TODO before a real Sunday

**Revert the testing schedule to production.** In
[Config/ServiceSchedule.swift](../Instrumentalist/Config/ServiceSchedule.swift):
1. Set `testMode = false` (turns off the half-hour intervals).
2. Re-add `comps.weekday = weekday` in `nextStart` so the countdown targets Sundays
   only again (currently it's daily for testing).

Both spots are flagged with comments in that file.

## New-machine setup gotchas (already hit + solved)

- **XcodeGen workflow:** `.xcodeproj` is generated from `project.yml` but also
  committed. After editing `project.yml` or adding/removing files, run
  `xcodegen generate` and commit `project.pbxproj`.
- **`Local.xcconfig` is gitignored** (signing). Recreate per machine:
  `printf 'DEVELOPMENT_TEAM = TF2E733E27\nCODE_SIGN_STYLE = Automatic\n' > Local.xcconfig`
  Missing it shows as "Recovered References / Local.xcconfig couldn't be opened".
- **Signing PLA:** if Xcode says "PLA Update available", accept the latest
  agreement at developer.apple.com/account, then Try Again.
- **Wireless run:** wireless debugging is per-Mac — connect the iPad by cable once,
  trust the computer, then enable "Connect via network" in Devices & Simulators.
