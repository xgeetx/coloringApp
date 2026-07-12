# Coloring App — project memory

iPad SwiftUI coloring app for 3-year-olds: a hub launcher + mini-apps (Coloring, Kids Mode, Spelling,
Trace, Weather-planned). GitHub `github.com/xgeetex/coloringApp`. **Full file structure, architecture
& design decisions, per-mini-app detail, known gotchas, the Swift Package Protocol, and current
status: [docs/CONTEXT.md](docs/CONTEXT.md).**

## ⚡ SESSION RESUME
At the start of this session, read `docs/plans/2026-02-27-weather-fun.md`, tell the user you're ready
to continue from Task 0 (Create Package Skeleton & Verify Build), then wait for their go-ahead.

## Machines & workflow
- **Edit** on the desktop: `/home/geet/Claude/coloringApp/`.
- **Build** on macOS: `/Users/claude/Dev/coloringApp/` (`ssh claude@192.168.50.251`).
- Workflow: edit on desktop → commit + push → SSH to Mac for `git pull` + `xcodebuild`.
- Xcode project `ColoringFun.xcodeproj` — iPad-only, iOS 15+, bundle `com.coloringapp.ColoringFun`,
  team `T2DJZ649J4`.

## Build / deploy
```bash
# Build (simulator) — from the desktop over SSH
ssh claude@192.168.50.251 "cd ~/Dev/coloringApp && git stash 2>/dev/null; git pull && \
  xcodebuild -project ColoringFun.xcodeproj -scheme ColoringFun \
  -destination 'platform=iOS Simulator,id=F90C33BE-82EB-474C-B566-8FAB43926C3B' build 2>&1 \
  | grep -E '(error:|BUILD)'"
```
- **Deploy to iPad:** must use **Terminal on the Mac as `garrettshannon`** — the `claude` SSH keychain
  locks during SSH sessions (`errSecInternalComponent` at CodeSign). Command:
  `xcodebuild -project ColoringFun.xcodeproj -scheme ColoringFun -destination 'id=<iPad UDID>' build`.
  iPad UDID: `28b1b65d4528209892b1ef4389dee775a537648b`.

## Hard rules
- **NEVER touch `project.pbxproj` from the desktop.** New main-target `.swift` files need ALL 4 pbxproj
  insertions (PBXBuildFile, PBXFileReference, PBXGroup children, PBXSourcesBuildPhase) — done on the
  Mac. New mini-apps follow the **Swift Package Protocol** (docs/CONTEXT.md); never hand-edit the
  pbxproj SPM sections.
- SSH deploys to the iPad fail as `claude` — use Terminal as `garrettshannon`.
- New mini-app → local Swift package under `Packages/XxxFun/`, registered per the protocol in CONTEXT.
