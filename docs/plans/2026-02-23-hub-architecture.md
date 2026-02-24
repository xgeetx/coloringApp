# Hub Architecture Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Add a "Kids Fun Zone" hub screen as the app root, with a 2×2 grid of app tiles — Coloring Fun is live; the three placeholders open a voice-dictation → email request sheet. Also drops the iOS deployment target from 16.0 → 15.0.

**Architecture:** `HubView` replaces `ContentView` as the app root. Available tiles use `fullScreenCover(item:)` to present apps full-screen. Placeholder tiles present `AppRequestView` as a sheet, which uses `SFSpeechRecognizer` for live transcription and `MFMailComposeViewController` (wrapped in `UIViewControllerRepresentable`) to send the request email.

**Tech Stack:** SwiftUI, Speech framework (`SFSpeechRecognizer`, `AVAudioEngine`), MessageUI (`MFMailComposeViewController`), Xcode 15, iOS 15+.

---

### Task 1: Drop deployment target to iOS 15

**Files:**
- Modify: `ColoringFun.xcodeproj/project.pbxproj` (4 occurrences of `IPHONEOS_DEPLOYMENT_TARGET`)

**Step 1: Edit project.pbxproj**

Replace all four occurrences of `IPHONEOS_DEPLOYMENT_TARGET = 16.0;` with `IPHONEOS_DEPLOYMENT_TARGET = 15.0;`.

They appear on lines 175, 198, 217, 235 (all four build configurations: project Debug, project Release, target Debug, target Release).

**Step 2: Verify**

```bash
grep -c "IPHONEOS_DEPLOYMENT_TARGET = 15.0" ColoringFun.xcodeproj/project.pbxproj
```
Expected output: `4`

**Step 3: Commit**

```bash
git add ColoringFun.xcodeproj/project.pbxproj
git commit -m "chore: drop iOS deployment target to 15.0"
```

---

### Task 2: Create AppRegistry.swift

**Files:**
- Create: `ColoringApp/AppRegistry.swift`

**Step 1: Write the file**

```swift
import SwiftUI

// MARK: - App Descriptor

struct MiniAppDescriptor: Identifiable {
    let id: String
    let displayName: String
    let subtitle: String
    let icon: String          // emoji
    let tileColor: Color
    let isAvailable: Bool
    let makeRootView: () -> AnyView

    static func placeholder(id: String, icon: String, displayName: String) -> MiniAppDescriptor {
        MiniAppDescriptor(
            id: id,
            displayName: displayName,
            subtitle: "Coming Soon",
            icon: icon,
            tileColor: Color(r: 210, g: 210, b: 230),
            isAvailable: false,
            makeRootView: { AnyView(EmptyView()) }
        )
    }
}

// MARK: - Registry

enum AppRegistry {
    static let apps: [MiniAppDescriptor] = [
        MiniAppDescriptor(
            id: "coloring",
            displayName: "Coloring Fun",
            subtitle: "Draw & Stamp!",
            icon: "🎨",
            tileColor: Color(r: 255, g: 150, b: 180),
            isAvailable: true,
            makeRootView: { AnyView(ContentView()) }
        ),
        .placeholder(id: "app2", icon: "🎵", displayName: "Music Maker"),
        .placeholder(id: "app3", icon: "🧩", displayName: "Puzzle Play"),
        .placeholder(id: "app4", icon: "📖", displayName: "Story Time"),
    ]
}
```

Note: `Color(r:g:b:)` is already defined in `Models.swift` — no duplication needed.

**Step 2: Commit**

```bash
git add ColoringApp/AppRegistry.swift
git commit -m "feat: add AppRegistry and MiniAppDescriptor"
```

---

### Task 3: Create HubView.swift

**Files:**
- Create: `ColoringApp/HubView.swift`

**Step 1: Write the file**

```swift
import SwiftUI

// MARK: - Hub Screen

struct HubView: View {
    @State private var activeApp: MiniAppDescriptor? = nil
    @State private var requestingApp: MiniAppDescriptor? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 24),
        GridItem(.flexible(), spacing: 24),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(r: 255, g: 200, b: 220),
                    Color(r: 255, g: 230, b: 180),
                    Color(r: 200, g: 230, b: 255),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                // Title
                VStack(spacing: 8) {
                    Text("🌟")
                        .font(.system(size: 48))
                    Text("Kids Fun Zone")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .green, .blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .padding(.top, 36)

                // App tiles
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(AppRegistry.apps) { app in
                        AppTileView(app: app) {
                            if app.isAvailable {
                                activeApp = app
                            } else {
                                requestingApp = app
                            }
                        }
                    }
                }
                .padding(.horizontal, 48)

                Spacer()
            }
        }
        .fullScreenCover(item: $activeApp) { app in
            app.makeRootView()
        }
        .sheet(item: $requestingApp) { app in
            AppRequestView(app: app)
        }
    }
}

// MARK: - App Tile

struct AppTileView: View {
    let app: MiniAppDescriptor
    let onTap: () -> Void

    @State private var pressed = false

    var body: some View {
        Button {
            pressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { pressed = false }
            onTap()
        } label: {
            VStack(spacing: 14) {
                Text(app.icon)
                    .font(.system(size: 72))

                Text(app.displayName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(app.isAvailable ? .white : Color(r: 110, g: 110, b: 130))

                Text(app.subtitle)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(app.isAvailable ? .white.opacity(0.85) : Color(r: 150, g: 150, b: 170))

                if !app.isAvailable {
                    Text("Tap to request!")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.35)))
                        .foregroundStyle(Color(r: 100, g: 100, b: 130))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(app.isAvailable ? app.tileColor : Color(r: 225, g: 225, b: 240))
                    .shadow(
                        color: app.isAvailable ? app.tileColor.opacity(0.45) : .gray.opacity(0.15),
                        radius: app.isAvailable ? 18 : 6,
                        x: 0, y: 6
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(.white.opacity(0.45), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: pressed)
    }
}

#Preview {
    HubView()
}
```

**Step 2: Commit**

```bash
git add ColoringApp/HubView.swift
git commit -m "feat: add HubView with 2x2 app tile grid"
```

---

### Task 4: Create AppRequestView.swift

**Files:**
- Create: `ColoringApp/AppRequestView.swift`

This file has three parts:
1. `AppRequestView` — the sheet driving a 3-phase flow (prompt → recording → review)
2. `MailComposeView` — thin `UIViewControllerRepresentable` wrapper around `MFMailComposeViewController`

**Step 1: Write the file**

```swift
import SwiftUI
import Speech
import AVFoundation
import MessageUI

// MARK: - App Request Sheet

struct AppRequestView: View {
    let app: MiniAppDescriptor
    @Environment(\.dismiss) private var dismiss

    enum Phase { case prompt, recording, review }

    @State private var phase: Phase = .prompt
    @State private var transcript: String = ""
    @State private var showMailCompose = false
    @State private var permissionDenied = false

    // Speech recognition handles
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @State private var audioEngine: AVAudioEngine? = nil
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest? = nil
    @State private var recognitionTask: SFSpeechRecognitionTask? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 28) {
                    // App identity header
                    VStack(spacing: 8) {
                        Text(app.icon)
                            .font(.system(size: 64))
                        Text(app.displayName)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("Want to ask for this app?")
                            .font(.system(size: 17))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 24)

                    switch phase {
                    case .prompt:   promptView
                    case .recording: recordingView
                    case .review:   reviewView
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        stopRecording()
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showMailCompose) {
            MailComposeView(
                toEmail: "quintus851@gmail.com",
                subject: "App Request: \(app.displayName)",
                body: transcript
            ) { _ in
                showMailCompose = false
                dismiss()
            }
        }
    }

    // MARK: - Phase: Prompt

    private var promptView: some View {
        VStack(spacing: 16) {
            if permissionDenied {
                Label("Microphone or speech access denied. Enable in Settings.", systemImage: "mic.slash")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                requestPermissionsAndStart()
            } label: {
                Label("Ask for it! 🎤", systemImage: "mic.fill")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.purple)
                            .shadow(color: .purple.opacity(0.4), radius: 8, y: 4)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Phase: Recording

    private var recordingView: some View {
        VStack(spacing: 20) {
            ScrollView {
                Text(transcript.isEmpty ? "Listening…" : transcript)
                    .font(.system(size: 17))
                    .foregroundStyle(transcript.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.secondarySystemBackground))
                    )
            }
            .frame(maxHeight: 200)

            Image(systemName: "mic.fill")
                .font(.system(size: 32))
                .foregroundStyle(.red)
                .padding()
                .background(Circle().fill(Color.red.opacity(0.12)))

            Button {
                stopRecording()
                phase = .review
            } label: {
                Label("Stop 🛑", systemImage: "stop.circle.fill")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.red))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Phase: Review

    private var reviewView: some View {
        VStack(spacing: 16) {
            Text("Edit your message, then send:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextEditor(text: $transcript)
                .font(.system(size: 16))
                .padding(8)
                .frame(height: 160)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                )

            HStack(spacing: 16) {
                Button("Start Over") {
                    phase = .prompt
                    transcript = ""
                }
                .foregroundStyle(.secondary)

                Button {
                    showMailCompose = true
                } label: {
                    Label("Send Request 📨", systemImage: "envelope.fill")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(MFMailComposeViewController.canSendMail() ? Color.blue : Color.gray)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!MFMailComposeViewController.canSendMail())
            }

            if !MFMailComposeViewController.canSendMail() {
                Text("Mail is not configured on this device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Speech Recognition

    private func requestPermissionsAndStart() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    permissionDenied = true
                    return
                }
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        if granted { startRecording() } else { permissionDenied = true }
                    }
                }
            }
        }
    }

    private func startRecording() {
        let engine = AVAudioEngine()
        audioEngine = engine

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, error in
            if let result = result {
                transcript = result.bestTranscription.formattedString
            }
            if error != nil || result?.isFinal == true {
                DispatchQueue.main.async {
                    stopRecording()
                    if phase == .recording { phase = .review }
                }
            }
        }

        try? AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement,
                                                          options: .duckOthers)
        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)

        engine.prepare()
        do {
            try engine.start()
            phase = .recording
        } catch {
            stopRecording()
        }
    }

    private func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false,
                                                       options: .notifyOthersOnDeactivation)
    }
}

// MARK: - Mail Compose Wrapper

struct MailComposeView: UIViewControllerRepresentable {
    let toEmail: String
    let subject: String
    let body: String
    let onDismiss: (MFMailComposeResult) -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients([toEmail])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController,
                                context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onDismiss: (MFMailComposeResult) -> Void
        init(onDismiss: @escaping (MFMailComposeResult) -> Void) { self.onDismiss = onDismiss }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
            onDismiss(result)
        }
    }
}
```

**Step 2: Commit**

```bash
git add ColoringApp/AppRequestView.swift
git commit -m "feat: add AppRequestView with live speech dictation and email compose"
```

---

### Task 5: Update ColoringApp.swift — swap root view

**Files:**
- Modify: `ColoringApp/ColoringApp.swift`

**Step 1: Replace `ContentView()` with `HubView()`**

Current content (lines 1–11):
```swift
import SwiftUI

@main
struct ColoringFunApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
    }
}
```

Replace `ContentView()` with `HubView()`:
```swift
import SwiftUI

@main
struct ColoringFunApp: App {
    var body: some Scene {
        WindowGroup {
            HubView()
                .preferredColorScheme(.light)
        }
    }
}
```

**Step 2: Commit**

```bash
git add ColoringApp/ColoringApp.swift
git commit -m "feat: set HubView as app root"
```

---

### Task 6: Update TopToolbarView.swift — add Home button

**Files:**
- Modify: `ColoringApp/TopToolbarView.swift`

**Step 1: Add `@Environment(\.dismiss)` and Home button**

Add `@Environment(\.dismiss) private var dismiss` below the existing `@State` properties.

Then add a Home `ToolbarButton` as the first element inside the `HStack(spacing: 14)` body, before the app title:

```swift
// Home button (leftmost)
ToolbarButton(
    icon: "house.fill",
    label: "Home",
    color: .indigo,
    disabled: false,
    action: { dismiss() }
)
```

The resulting HStack order will be: Home | [title spacer] | Background | Undo | Clear.

Full updated `TopToolbarView.body`:
```swift
var body: some View {
    HStack(spacing: 14) {
        // Home
        ToolbarButton(
            icon: "house.fill",
            label: "Home",
            color: .indigo,
            disabled: false,
            action: { dismiss() }
        )

        // App title
        HStack(spacing: 6) {
            Text("🎨")
                .font(.system(size: 28))
            Text("Coloring Fun!")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }

        Spacer()

        // Background color picker
        Button {
            showBgColorPicker = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.fill")
                    .foregroundStyle(state.backgroundColor)
                    .font(.system(size: 18))
                    .shadow(color: .black.opacity(0.2), radius: 1)
                Text("Background")
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.1), radius: 3)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showBgColorPicker) {
            BackgroundColorPickerView(state: state)
        }

        // Undo
        ToolbarButton(
            icon: "arrow.uturn.backward",
            label: "Undo",
            color: .blue,
            disabled: !state.canUndo,
            action: { state.undo() }
        )

        // Clear
        ToolbarButton(
            icon: "trash",
            label: "Clear",
            color: .red,
            disabled: false,
            action: { showClearConfirm = true }
        )
        .confirmationDialog("Clear the whole drawing?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear It! 🗑️", role: .destructive) { state.clear() }
            Button("Keep It! 🎨", role: .cancel) {}
        }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(
        RoundedRectangle(cornerRadius: 18)
            .fill(.ultraThinMaterial)
            .shadow(color: .black.opacity(0.1), radius: 4)
    )
}
```

Also add `@Environment(\.dismiss) private var dismiss` inside the `TopToolbarView` struct, after the existing `@State` declarations:
```swift
@Environment(\.dismiss) private var dismiss
```

**Step 2: Commit**

```bash
git add ColoringApp/TopToolbarView.swift
git commit -m "feat: add Home button to TopToolbarView"
```

---

### Task 7: Update Info.plist — add permission strings

**Files:**
- Modify: `ColoringApp/Info.plist`

**Step 1: Add microphone and speech recognition usage descriptions**

Inside the root `<dict>`, add these two key-value pairs (before the closing `</dict>`):

```xml
<key>NSMicrophoneUsageDescription</key>
<string>To record your app request</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>To turn your voice into text for your app request</string>
```

**Step 2: Commit**

```bash
git add ColoringApp/Info.plist
git commit -m "chore: add microphone and speech recognition permission strings"
```

---

### Task 8: Update project.pbxproj — register new source files

**Files:**
- Modify: `ColoringFun.xcodeproj/project.pbxproj`

Three new Swift files need to be registered in the pbxproj: `AppRegistry.swift`, `HubView.swift`, `AppRequestView.swift`.

Each file needs:
1. A `PBXBuildFile` entry (links the file into the Sources build phase)
2. A `PBXFileReference` entry (describes the file on disk)
3. An entry in the `PBXGroup` children list (makes it visible in Xcode's file navigator)
4. An entry in the `PBXSourcesBuildPhase` files list (actually compiles it)

Use these fixed UUIDs (24-char hex, confirmed non-overlapping with existing ones):

| File | fileRef UUID | buildFile UUID |
|------|-------------|----------------|
| AppRegistry.swift | `AA01BB02CC03DD04EE05FF06` | `BA01CB02DC03ED04FE05AF06` |
| HubView.swift | `CC01DD02EE03FF04AA05BB06` | `DC01ED02FE03AF04BA05CB06` |
| AppRequestView.swift | `EE01FF02AA03BB04CC05DD06` | `FE01AF02BA03CB04DC05ED06` |

**Step 1: Add PBXBuildFile entries**

In the `/* Begin PBXBuildFile section */` block, append before `/* End PBXBuildFile section */`:

```
		BA01CB02DC03ED04FE05AF06 /* AppRegistry.swift in Sources */ = {isa = PBXBuildFile; fileRef = AA01BB02CC03DD04EE05FF06 /* AppRegistry.swift */; };
		DC01ED02FE03AF04BA05CB06 /* HubView.swift in Sources */ = {isa = PBXBuildFile; fileRef = CC01DD02EE03FF04AA05BB06 /* HubView.swift */; };
		FE01AF02BA03CB04DC05ED06 /* AppRequestView.swift in Sources */ = {isa = PBXBuildFile; fileRef = EE01FF02AA03BB04CC05DD06 /* AppRequestView.swift */; };
```

**Step 2: Add PBXFileReference entries**

In the `/* Begin PBXFileReference section */` block, append before `/* End PBXFileReference section */`:

```
		AA01BB02CC03DD04EE05FF06 /* AppRegistry.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AppRegistry.swift; sourceTree = "<group>"; };
		CC01DD02EE03FF04AA05BB06 /* HubView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = HubView.swift; sourceTree = "<group>"; };
		EE01FF02AA03BB04CC05DD06 /* AppRequestView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AppRequestView.swift; sourceTree = "<group>"; };
```

**Step 3: Add to PBXGroup children**

In the `7174CA134E46658D8B19601F /* ColoringApp */` group's `children` array, append before the closing `);`:

```
				AA01BB02CC03DD04EE05FF06 /* AppRegistry.swift */,
				CC01DD02EE03FF04AA05BB06 /* HubView.swift */,
				EE01FF02AA03BB04CC05DD06 /* AppRequestView.swift */,
```

**Step 4: Add to PBXSourcesBuildPhase files**

In the `FCA229C23F166EBB0BA5029E /* Sources */` build phase's `files` array, append before the closing `);`:

```
				BA01CB02DC03ED04FE05AF06 /* AppRegistry.swift in Sources */,
				DC01ED02FE03AF04BA05CB06 /* HubView.swift in Sources */,
				FE01AF02BA03CB04DC05ED06 /* AppRequestView.swift in Sources */,
```

**Step 5: Verify**

```bash
grep -c "AppRegistry\|HubView\|AppRequestView" ColoringFun.xcodeproj/project.pbxproj
```
Expected output: `12` (3 files × 4 places each)

**Step 6: Commit**

```bash
git add ColoringFun.xcodeproj/project.pbxproj
git commit -m "chore: register AppRegistry, HubView, AppRequestView in Xcode project"
```

---

### Task 9: Final integration — push to GitHub

**Step 1: Push all commits**

```bash
git push origin main
```

**Step 2: Pull on macOS**

```bash
git pull
open ColoringFun.xcodeproj
```

**Step 3: Verify in Xcode**

- Build succeeds (⌘B) with no errors
- Run on iPad simulator (iOS 15+)
- Hub screen shows 2×2 grid: Coloring Fun (pink) + 3 greyed-out placeholders
- Tap Coloring Fun → full-screen coloring app opens
- Tap Home button → returns to hub
- Tap a placeholder tile → AppRequestView sheet opens
- Tap "Ask for it! 🎤" → grants permissions, live transcription appears
- Tap Stop → transcript editable
- Tap Send Request → MFMailCompose sheet opens pre-filled to quintus851@gmail.com

---

## iOS 15 Compatibility Checklist

All APIs used are available on iOS 15+:

| API | Min iOS |
|-----|---------|
| `fullScreenCover(item:)` | 14.0 |
| `@Environment(\.dismiss)` | 15.0 |
| `LazyVGrid` | 14.0 |
| `.ultraThinMaterial` | 15.0 |
| `SFSpeechRecognizer` | 10.0 |
| `AVAudioEngine` | 8.0 |
| `MFMailComposeViewController` | 3.0 |
| `UIViewControllerRepresentable` | 13.0 |
| `NavigationView` | 13.0 |
| `TextEditor` | 14.0 |
