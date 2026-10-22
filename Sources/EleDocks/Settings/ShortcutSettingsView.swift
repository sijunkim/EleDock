import EleDocksCore
import SwiftUI

/// 단축키 탭: 최소화·복원 단축키 녹화와 기본값 복원.
struct ShortcutSettingsView: View {
    let state: AppState
    let settings: AppSettings
    let hotKeys: HotKeyCenter
    @StateObject private var model = ShortcutSettingsModel()
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
                SectionFooter(L("shortcut.help"))
            }
            Section {
                HStack {
                    Spacer()
                    Button(L("shortcut.reset")) {
                        settings.resetShortcuts()
                        hotKeys.update()
                    }
                }
            }
            MenuConflictsSection(model: conflicts, settings: settings)
        }
        .formStyle(.grouped)
        .frame(width: SettingsLayout.width, height: height)
        .onPreferenceChange(RecorderMessageCount.self) { model.messageCount = $0 }
    }

    private var height: CGFloat {
        SettingsLayout.shortcutsHeight + CGFloat(model.messageCount) * SettingsLayout.recorderMessageRowHeight
    }
}

private final class ShortcutSettingsModel: ObservableObject {
    @Published var messageCount = 0
}

/// 오류 문구를 보이고 있는 ShortcutRecorder 수.
struct RecorderMessageCount: PreferenceKey {
    static let defaultValue = 0

    static func reduce(value: inout Int, nextValue: () -> Int) {
        value += nextValue()
    }
}
