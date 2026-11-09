import AppKit
import EleDockCore
import SwiftUI

/// 단축키 녹화 버튼.
struct ShortcutRecorder: View {
    let kind: Shortcut.Kind
    @ObservedObject var state: AppState
    @ObservedObject var settings: AppSettings
    let hotKeys: HotKeyCenter
    @StateObject private var model = RecorderModel()

    var body: some View {
        let recording = state.recordingKind == kind
        let message = recording ? model.message : nil
        let failed = state.failedHotKeys.contains(kind)
        VStack(alignment: .trailing, spacing: SettingsLayout.recorderMessageSpacing) {
            Button {
                recording ? stop() : start()
            } label: {
                Text(recording ? L("shortcut.recording") : settings.shortcut(kind).displayString)
                    .frame(width: SettingsLayout.shortcutButtonWidth)
            }
            .buttonStyle(.bordered)
            if let message {
                Text(message).font(.caption).foregroundStyle(.red)
            } else if failed {
                Text(L("shortcut.registerFailed")).font(.caption).foregroundStyle(.red)
            }
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        model.message = nil
        hotKeys.startRecording(kind) { record($0) }
    }

    private func stop() {
        guard state.recordingKind == kind else { return }
        hotKeys.stopRecording()
    }

    private func record(_ event: NSEvent) {
        let shortcut = Shortcut(event: event)
        switch shortcut.recordingOutcome(other: settings.shortcut(kind.other)) {
        case .cancel:
            stop()
        case .missingModifier:
            model.message = L("shortcut.error.modifier")
        case .duplicate:
            model.message = L("shortcut.error.duplicate")
        case .accept:
            model.message = nil
            settings.setShortcut(shortcut, for: kind)
            stop()
        }
    }
}

private final class RecorderModel: ObservableObject {
    @Published var message: String?
}
