import Foundation
import AppKit
import Speech
import AVFoundation
import Combine

enum RecordingState: Equatable {
    case idle
    case recording
    case transcribing
    case error(String)

    static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.recording, .recording), (.transcribing, .transcribing): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

struct TranscriptionEntry: Identifiable {
    let id = UUID()
    let text: String
    let timestamp: Date
    let locale: String
}

@MainActor
final class TranscriptionEngine: ObservableObject {
    @Published var recordingState: RecordingState = .idle
    @Published var currentTranscription: String = ""
    @Published var history: [TranscriptionEntry] = []
    @Published var selectedLocale: Locale = {
        let device = Locale.current
        if SFSpeechRecognizer(locale: device) != nil { return device }
        return Locale(identifier: "en-US")
    }()

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var didFinish = false

    var isRecording: Bool {
        if case .recording = recordingState { return true }
        return false
    }

    func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speechStatus == .authorized else {
            recordingState = .error("Speech recognition permission denied. Enable in System Settings → Privacy.")
            return false
        }

        let micGranted = await withCheckedContinuation { cont in
            AVCaptureDevice.requestAccess(for: .audio) { cont.resume(returning: $0) }
        }
        guard micGranted else {
            recordingState = .error("Microphone permission denied. Enable in System Settings → Privacy.")
            return false
        }

        recordingState = .idle
        return true
    }

    func startRecording() async {
        guard !isRecording else { return }

        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        if speechStatus != .authorized || micStatus != .authorized {
            let granted = await requestPermissions()
            guard granted else { return }
        }

        speechRecognizer = SFSpeechRecognizer(locale: selectedLocale)

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            recordingState = .error("Speech recognizer unavailable for locale: \(selectedLocale.identifier)")
            return
        }

        do {
            try startAudioEngine(recognizer: recognizer)
        } catch {
            recordingState = .error("Audio engine failed: \(error.localizedDescription)")
        }
    }

    private func startAudioEngine(recognizer: SFSpeechRecognizer) throws {
        didFinish = false
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true
        // Prefer on-device model (no network needed); fall back to server if unavailable
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        recordingState = .recording
        currentTranscription = ""

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let result {
                    self.currentTranscription = result.bestTranscription.formattedString
                }

                if let error {
                    let nsError = error as NSError
                    // 301 = no speech / end of utterance (normal), 1110 = cancelled
                    let isBenign = nsError.code == 301 || nsError.code == 1110
                    let isFinal = result?.isFinal ?? false
                    if !isBenign && !isFinal {
                        let message = self.humanReadableSpeechError(nsError)
                        self.recordingState = .error(message)
                    }
                }

                if result?.isFinal == true {
                    self.finishTranscription()
                }
            }
        }
    }

    private func humanReadableSpeechError(_ error: NSError) -> String {
        // kAFAssistantErrorDomain 203 = speech service unreachable (network / Siri backend)
        if error.code == 203 || error.domain == "SiriSpeechErrorDomain" {
            return "Speech service unavailable. Check internet connection or download the \(selectedLocale.identifier) on-device model in System Settings → Siri & Dictation."
        }
        return error.localizedDescription
    }

    func stopRecording() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recordingState = .transcribing

        // Fallback: if recognition doesn't deliver isFinal within 4 seconds, finish manually
        Task {
            try? await Task.sleep(for: .seconds(4))
            if case .transcribing = self.recordingState {
                self.recognitionTask?.cancel()
                self.finishTranscription()
            }
        }
    }

    private func finishTranscription() {
        guard !didFinish else { return }
        didFinish = true

        recognitionTask = nil
        recognitionRequest = nil

        let text = currentTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            let entry = TranscriptionEntry(
                text: text,
                timestamp: Date(),
                locale: selectedLocale.identifier
            )
            history.insert(entry, at: 0)
            copyToClipboard(text)
        }

        recordingState = .idle
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func clearHistory() {
        history.removeAll()
        currentTranscription = ""
    }

    func setLocale(_ locale: Locale) {
        guard !isRecording else { return }
        selectedLocale = locale
    }
}
