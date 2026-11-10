import Combine
import EleDockCore
import Sparkle
import SwiftUI

/// 일반 섹션: 언어, 로그인 항목, 단축키·연속 동작, 업데이트.
struct GeneralSettingsView: View {
    let updater: SPUUpdater?
    @ObservedObject var settings: AppSettings
    @ObservedObject var loginItems: LoginItemController
    @State private var automaticallyChecks: Bool

    init(updater: SPUUpdater?, settings: AppSettings, loginItems: LoginItemController) {
        self.updater = updater
        self.settings = settings
        self.loginItems = loginItems
        _automaticallyChecks = State(initialValue: updater?.automaticallyChecksForUpdates ?? false)
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
                Toggle(L("settings.hotkeys"), isOn: $settings.hotKeysEnabled)
                Toggle(isOn: $settings.holdToRepeat) {
                    Text(L("settings.holdToRepeat")).dimmed(!settings.hotKeysEnabled)
                }
                .disabled(!settings.hotKeysEnabled)
            } footer: {
                SectionFooter(String(format: L("settings.holdToRepeat.help"), RepeatPolicy.interval.formatted()))
            }
            Section {
                Toggle(
                    L("settings.autoUpdate"),
                    isOn: Binding(
                        get: { automaticallyChecks },
                        set: { updater?.automaticallyChecksForUpdates = $0 })
                )
                .disabled(updater == nil)
                .onReceive(automaticallyChecksChanges) { automaticallyChecks = $0 }
            }
        }
        .formStyle(.grouped)
        .onAppear { loginItems.refresh() }
    }

    // Sparkle 이 "업데이트 자동 확인" 값을 바꿀 때마다 보내는 새 값.
    private var automaticallyChecksChanges: AnyPublisher<Bool, Never> {
        updater?.publisher(for: \.automaticallyChecksForUpdates, options: .new).eraseToAnyPublisher()
            ?? Empty().eraseToAnyPublisher()
    }
}
