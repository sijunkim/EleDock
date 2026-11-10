import EleDockCore
import SwiftUI

/// 단축키 섹션: 최소화·복원 단축키 녹화와 기본값 복원.
struct ShortcutSettingsView: View {
    let state: AppState
    let settings: AppSettings
    let hotKeys: HotKeyCenter
    @StateObject private var conflicts: MenuConflictsModel

    init(state: AppState, settings: AppSettings, hotKeys: HotKeyCenter) {
        self.state = state
        self.settings = settings
        self.hotKeys = hotKeys
        _conflicts = StateObject(wrappedValue: MenuConflictsModel(settings: settings))
    }

    var body: some View {
        Form {
            Section {
                LabeledContent(L("shortcut.minimize")) {
                    ShortcutRecorder(kind: .minimize, state: state, settings: settings, hotKeys: hotKeys)
                }
                LabeledContent(L("shortcut.restore")) {
                    ShortcutRecorder(kind: .restore, state: state, settings: settings, hotKeys: hotKeys)
                }
            } footer: {
                VStack(alignment: .trailing) {
                    SectionFooter(L("shortcut.help"))
                    Button(action: settings.resetShortcuts) {
                        Text(L("shortcut.reset")).frame(width: SettingsLayout.shortcutButtonWidth)
                    }
                    .buttonStyle(.bordered)
                }
            }
            MenuConflictsSection(model: conflicts, settings: settings)
        }
        .formStyle(.grouped)
    }
}
