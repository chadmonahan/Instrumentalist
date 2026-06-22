# Hymns (Instrumentalist)

A kiosk iPad/iOS hymn player for Sunday services — prelude/opening/memorial/
closing/postlude slots, a number pad, system-volume control, and a prelude
countdown with auto-play so the prelude finishes right as the service starts.

- Display name: **Hymns**
- Bundle id: `com.chadmonahan.instrumentalist`
- Min iOS: 17.0 · iPad + iPhone

## Project setup

The Xcode project is defined by [`project.yml`](project.yml) and generated with
[XcodeGen](https://github.com/yonaskolb/XcodeGen). The generated
`Instrumentalist.xcodeproj` **is committed** so the repo clones and opens without
any extra steps — but it's still generated, so treat `project.yml` as the source
of truth and regenerate after changing it.

Signing is kept out of git in `Local.xcconfig` (machine-specific). You create
that file once per machine from the provided template.

### First-time setup on a new machine

```bash
git clone https://github.com/chadmonahan/Instrumentalist.git
cd Instrumentalist

# Local signing config (gitignored) — set your Apple Developer team id.
cp Local.xcconfig.example Local.xcconfig
#   then edit Local.xcconfig and set DEVELOPMENT_TEAM

open Instrumentalist.xcodeproj      # already committed — just open and Run
```

If you'd rather (re)generate the project, or after editing `project.yml`:

```bash
brew install xcodegen   # once
xcodegen generate
```

### When you add or remove source files

XcodeGen picks up everything under `Instrumentalist/` by folder, so after adding
or removing files run `xcodegen generate` and commit the updated `project.pbxproj`.

## What git ignores

`build/`, `DerivedData/`, per-user Xcode state (`xcuserdata/`, `*.xcuserstate`),
`Local.xcconfig`, and `.DS_Store`. The shared project files are tracked.
