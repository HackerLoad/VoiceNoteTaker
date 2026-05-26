import SwiftUI
import AppKit

struct PopoverView: View {
    @ObservedObject var engine: TranscriptionEngine

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            if engine.isRecording || engine.recordingState == .transcribing {
                livePanel
                Divider()
            }
            historyContent
        }
        .frame(width: 380, height: 500)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            statusDot
            Text("VoiceNoteTaker")
                .font(.headline)
            Spacer()
            if !engine.history.isEmpty {
                Button("Clear All") { engine.clearHistory() }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var statusDot: some View {
        Circle()
            .frame(width: 8, height: 8)
            .foregroundColor(dotColor)
            .animation(.easeInOut(duration: 0.3), value: engine.recordingState)
    }

    private var dotColor: Color {
        switch engine.recordingState {
        case .idle:         return .secondary
        case .recording:    return .red
        case .transcribing: return .orange
        case .error:        return .yellow
        }
    }

    // MARK: - Live Panel

    private var livePanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if engine.recordingState == .transcribing {
                    ProgressView().scaleEffect(0.6)
                    Text("Processing…").font(.caption).foregroundColor(.orange)
                } else {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text("Recording").font(.caption).foregroundColor(.red)
                    Text("· \(engine.selectedLocale.identifier)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Text(engine.currentTranscription.isEmpty ? "Listening…" : engine.currentTranscription)
                .font(.body)
                .foregroundColor(engine.currentTranscription.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }

    // MARK: - History

    private var historyContent: some View {
        Group {
            if engine.history.isEmpty {
                emptyState
            } else {
                List(engine.history) { entry in
                    HistoryEntryRow(entry: entry)
                        .listRowSeparator(.visible)
                }
                .listStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "mic.slash")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("No transcriptions yet")
                .foregroundColor(.secondary)
            Text("Press ⌘⇧R or click the menu bar icon to start")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }
}

// MARK: - History Entry Row

struct HistoryEntryRow: View {
    let entry: TranscriptionEntry
    @State private var copyLabel = "Copy"

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.text)
                .font(.body)
                .textSelection(.enabled)
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(Self.formatter.string(from: entry.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("·")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text(Locale.current.localizedString(forIdentifier: entry.locale) ?? entry.locale)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(copyLabel) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.text, forType: .string)
                    copyLabel = "Copied!"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copyLabel = "Copy"
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundColor(copyLabel == "Copied!" ? .green : .accentColor)
            }
        }
        .padding(.vertical, 4)
    }
}
