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
        // 1. Configure audio session FIRST so inputNode reports correct format
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement,
                                                             options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            return
        }

        let engine = AVAudioEngine()
        audioEngine = engine

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        // 2. Now get format (reflects active session)
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, error in
            DispatchQueue.main.async {
                if let result = result {
                    transcript = result.bestTranscription.formattedString
                }
                if error != nil || result?.isFinal == true {
                    stopRecording()
                    if phase == .recording { phase = .review }
                }
            }
        }

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
