# Hub Architecture Design
**Date:** 2026-02-23
**Status:** Approved

## Overview

Add a "Kids Fun Zone" hub/launcher screen as the new app root. The hub shows a 2×2 grid of app tiles. Coloring Fun is the only live app; the other three are placeholders that let a parent dictate an app-request email via live speech-to-text.

Also drops the iOS deployment target from 16.0 → 15.0 for broader iPad compatibility.

---

## Architecture

### Navigation model

```
ColoringFunApp (@main)
  └── HubView  ← new root
        ├── fullScreenCover(item: $activeApp)
        │     └── ContentView()  ← coloring app
        │           └── TopToolbarView has 🏠 Home button → @Environment(\.dismiss)
        └── sheet(item: $requestingApp)
              └── AppRequestView  ← voice dictation → email
```

### Files

**Create:**
- `ColoringApp/AppRegistry.swift` — `MiniAppDescriptor` struct + `AppRegistry.apps`
- `ColoringApp/HubView.swift` — 2×2 LazyVGrid, fullScreenCover navigation
- `ColoringApp/AppRequestView.swift` — dictation sheet + MFMailCompose

**Modify:**
- `ColoringApp/ColoringApp.swift` — root: `ContentView()` → `HubView()`
- `ColoringApp/TopToolbarView.swift` — add 🏠 Home button (leftmost in HStack)
- `ColoringApp/Info.plist` — add microphone + speech recognition usage descriptions
- `ColoringFun.xcodeproj/project.pbxproj` — drop all 4 deployment targets 16.0 → 15.0; add 3 new source files

---

## AppRegistry

```swift
struct MiniAppDescriptor: Identifiable {
    let id: String
    let displayName: String
    let subtitle: String
    let icon: String          // emoji
    let tileColor: Color
    let isAvailable: Bool
    let makeRootView: () -> AnyView

    static func placeholder(id: String, icon: String, displayName: String) -> Self {
        MiniAppDescriptor(id: id, displayName: displayName, subtitle: "Coming Soon",
            icon: icon, tileColor: .gray, isAvailable: false,
            makeRootView: { AnyView(EmptyView()) })
    }
}

enum AppRegistry {
    static let apps: [MiniAppDescriptor] = [
        MiniAppDescriptor(id: "coloring", displayName: "Coloring Fun",
            subtitle: "Draw & Stamp!", icon: "🎨",
            tileColor: .pink, isAvailable: true,
            makeRootView: { AnyView(ContentView()) }),
        .placeholder(id: "app2", icon: "🎵", displayName: "Music Maker"),
        .placeholder(id: "app3", icon: "🧩", displayName: "Puzzle Play"),
        .placeholder(id: "app4", icon: "📖", displayName: "Story Time"),
    ]
}
```

Future apps are added by appending one entry to `AppRegistry.apps` — no other changes needed.

---

## HubView

- Background: cheerful linear gradient (matches existing app aesthetic)
- Title: "Kids Fun Zone" with rainbow gradient, large rounded font
- 2×2 `LazyVGrid` of large square tiles (min ~280pt)
- Available tiles: colorful, full opacity, tap → `fullScreenCover`
- Placeholder tiles: desaturated/dimmed, "Coming Soon" badge, tap → `sheet(AppRequestView)`
- Tile contents: big emoji icon, app name, subtitle label

---

## AppRequestView

Flow:
1. Sheet opens showing the tile's name + "Want to ask for this app?"
2. "Ask for it! 🎤" starts `SFSpeechRecognizer` + `AVAudioEngine`; live transcript displayed in a styled bubble
3. "Stop 🛑" ends recording; transcript becomes editable via `TextEditor`
4. "Send Request 📨" → `MFMailComposeViewController`:
   - To: quintus851@gmail.com
   - Subject: "App Request: {displayName}"
   - Body: transcript text
5. Cancel / dismiss at any point

### Permissions (Info.plist additions)
- `NSMicrophoneUsageDescription` — "To record your app request"
- `NSSpeechRecognitionUsageDescription` — "To turn your voice into text for your app request"

---

## iOS 15 Compatibility

All APIs used are iOS 15+:
- `fullScreenCover(item:)` — iOS 14+
- `@Environment(\.dismiss)` — iOS 15+
- `SFSpeechRecognizer` — iOS 10+
- `MFMailComposeViewController` — iOS 3+
- `LazyVGrid` — iOS 14+
- `.ultraThinMaterial` — iOS 15+

Change: drop `IPHONEOS_DEPLOYMENT_TARGET` from `16.0` → `15.0` in all 4 build configs in `project.pbxproj`.

---

## Task IDs

- Task #7 — Implement AppRegistry.swift
- Task #8 — Implement HubView.swift
- Task #9 — Implement AppRequestView.swift
- Task #10 — Modify ColoringApp.swift (swap root view)
- Task #11 — Modify TopToolbarView.swift (add Home button)
- Task #12 — Update Info.plist (permissions)
- Task #13 — Update project.pbxproj (deployment target + new files)
