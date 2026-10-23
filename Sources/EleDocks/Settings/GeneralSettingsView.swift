import EleDocksCore
import Sparkle
import SwiftUI

/// 일반 섹션: 언어, 로그인 항목, 단축키·연속 동작, 업데이트.
struct GeneralSettingsView: View {
    let updater: SPUUpdater?
    @ObservedObject var settings: AppSettings
    @ObservedObject var loginItems: LoginItemController
    let hotKeys: HotKeyCenter
    @StateObject private var model: GeneralSettingsModel

    init(updater: SPUUpdater?, settings: AppSettings, loginItems: LoginItemController, hotKeys: HotKeyCenter) {
        self.updater = updater
        self.settings = settings
        self.loginItems = loginItems
        self.hotKeys = hotKeys
        _model = StateObject(wrappedValue: GeneralSettingsModel(updater: updater))
    }

    var body: some View {
        Form {
            Section {
                Picker(L("settings.language"), selection: $settings.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(language.nativeName ?? L("settings.language.system")).tag(language)
                    }
                }
                if settings.languageNeedsRelaunch {
                    HStack {
                        Text(L("settings.language.restart")).foregroundStyle(.secondary)
                        Spacer()
                        Button(L("settings.relaunch"), action: Relauncher.relaunchAndTerminate)
                    }
                }
            }
            Section {
                Toggle(
                    loginItems.label(L("settings.login"), approval: L("settings.login.approval")),
                    isOn: Binding(
                        get: { loginItems.isEnabled },
                        set: { _ in loginItems.toggle() }))
            }
            Section {
                Toggle(
                    L("settings.hotkeys"),
                    isOn: Binding(
                        get: { settings.hotKeysEnabled },
                        set: { hotKeys.setEnabled($0) }))
                Toggle(isOn: $settings.holdToRepeat) {
                    Text(L("settings.holdToRepeat")).dimmed(!settings.hotKeysEnabled)
                }
                .disabled(!settings.hotKeysEnabled)
            } footer: {
                SectionFooter(L("settings.holdToRepeat.help"))
            }
            Section {
                Toggle(
                    L("settings.autoUpdate"),
                    isOn: Binding(
                        get: { model.automaticallyChecks },
                        set: {
                            model.automaticallyChecks = $0
                            updater?.automaticallyChecksForUpdates = $0
                        })
                )
                .disabled(updater == nil)
            }
        }
        .formStyle(.grouped)
        .onAppear { loginItems.refresh() }
    }
}

// 일반 섹션의 화면 상태.
private final class GeneralSettingsModel: ObservableObject {
    @Published var automaticallyChecks: Bool

    init(updater: SPUUpdater?) {
        automaticallyChecks = updater?.automaticallyChecksForUpdates ?? false
    }
}
