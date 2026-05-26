import AppKit
import SwiftUI
import Combine

@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let engine: TranscriptionEngine
    private var cancellables = Set<AnyCancellable>()
    private var globalHotkeyMonitor: Any?

    init(engine: TranscriptionEngine) {
        self.engine = engine
        super.init()
        setupStatusItem()
        setupPopover()
        observeEngine()
        setupGlobalHotkey()
    }

    deinit {
        if let monitor = globalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon(for: .idle)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleClick(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 500)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(engine: engine)
        )
    }

    private func observeEngine() {
        engine.$recordingState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.updateIcon(for: state) }
            .store(in: &cancellables)
    }

    private func setupGlobalHotkey() {
        // Cmd+Shift+R (keyCode 15 = R)
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.intersection([.command, .shift, .control, .option]) == [.command, .shift],
                  event.keyCode == 15 else { return }
            Task { @MainActor in self?.toggleRecording() }
        }
    }

    // MARK: - Actions

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            toggleRecording()
        }
    }

    private func toggleRecording() {
        Task { @MainActor in
            if self.engine.isRecording {
                self.engine.stopRecording()
            } else {
                await self.engine.startRecording()
            }
        }
    }

    // MARK: - Menu

    private func showMenu() {
        let menu = buildMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // Toggle recording
        let isRecording = engine.isRecording
        let toggleTitle = isRecording ? "Stop Recording" : "Start Recording  ⌘⇧R"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(menuToggleRecording), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        // Live preview while recording
        if isRecording, !engine.currentTranscription.isEmpty {
            menu.addItem(.separator())
            let preview = String(engine.currentTranscription.prefix(70))
            let item = NSMenuItem(title: preview, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        // Error message
        if case .error(let msg) = engine.recordingState {
            menu.addItem(.separator())
            let item = NSMenuItem(title: "⚠️ \(msg)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())

        // History popover
        let histCount = engine.history.count
        let histTitle = histCount == 0 ? "No Transcriptions" : "Show History (\(histCount))"
        let histItem = NSMenuItem(title: histTitle, action: histCount > 0 ? #selector(showHistory) : nil, keyEquivalent: "")
        histItem.target = self
        menu.addItem(histItem)

        // Language submenu
        let langItem = NSMenuItem(title: "Language: \(localeName(engine.selectedLocale))", action: nil, keyEquivalent: "")
        langItem.submenu = buildLanguageMenu()
        menu.addItem(langItem)

        // Clear history
        let clearItem = NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        clearItem.isEnabled = histCount > 0
        menu.addItem(clearItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit VoiceNoteTaker", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }

    private func buildLanguageMenu() -> NSMenu {
        let menu = NSMenu()
        let locales: [(String, String)] = [
            ("English (US)",          "en-US"),
            ("English (UK)",          "en-GB"),
            ("German",                "de-DE"),
            ("French",                "fr-FR"),
            ("Spanish",               "es-ES"),
            ("Italian",               "it-IT"),
            ("Portuguese (Brazil)",   "pt-BR"),
            ("Japanese",              "ja-JP"),
            ("Chinese (Simplified)",  "zh-CN"),
        ]
        for (name, id) in locales {
            let item = NSMenuItem(title: name, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.representedObject = id
            item.target = self
            item.state = engine.selectedLocale.identifier == id ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    private func localeName(_ locale: Locale) -> String {
        Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
    }

    @objc private func menuToggleRecording() { toggleRecording() }

    @objc private func showHistory() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc private func clearHistory() {
        engine.clearHistory()
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        engine.setLocale(Locale(identifier: id))
    }

    // MARK: - Icon

    private func updateIcon(for state: RecordingState) {
        guard let button = statusItem.button else { return }
        switch state {
        case .idle:
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Voice Transcriber")
            button.contentTintColor = nil
        case .recording:
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Recording")
            button.contentTintColor = .systemRed
        case .transcribing:
            button.image = NSImage(systemSymbolName: "ellipsis.bubble.fill", accessibilityDescription: "Transcribing")
            button.contentTintColor = .systemOrange
        case .error:
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Error")
            button.contentTintColor = .systemYellow
        }
    }
}
