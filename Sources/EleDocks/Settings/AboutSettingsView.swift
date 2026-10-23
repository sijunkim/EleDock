import AppKit
import Sparkle
import SwiftUI

/// 정보 섹션: 앱 아이콘, 워드마크, 버전, 업데이트 확인.
struct AboutSettingsView: View {
    let updater: SPUUpdater?
    @ObservedObject var state: AppState

    var body: some View {
        Form {
            Section {
                LabeledContent(L("about.version")) {
                    HStack {
                        Text(version)
                            .foregroundStyle(.secondary)
                        Button(L("update.check")) { updater?.checkForUpdates() }
                            .disabled(!state.canCheckForUpdates)
                    }
                }
            } header: {
                VStack(spacing: SettingsLayout.aboutSpacing) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: SettingsLayout.aboutIconSize, height: SettingsLayout.aboutIconSize)
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("Ele")
                            .font(
                                .system(size: SettingsLayout.wordmarkEleSize, weight: .semibold, design: .serif)
                                    .italic()
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(nsColor: Brand.gradientTop), Color(nsColor: Brand.gradientBottom)],
                                    startPoint: .top, endPoint: .bottom))
                        Text("Docks")
                            .font(.system(size: SettingsLayout.wordmarkDocksSize, weight: .semibold))
                    }
                    Text("ELEGANCE + DOCK")
                        .font(.caption)
                        .tracking(SettingsLayout.brandTracking)
                        .foregroundStyle(.secondary)
                    Text(L("about.tagline"))
                        .font(.body)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, SettingsLayout.aboutSpacing)
            } footer: {
                VStack(spacing: SettingsLayout.aboutSpacing) {
                    Text(L("about.website"))
                    Text("© 2026 EleDocks")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, SettingsLayout.aboutSpacing)
            }
        }
        .formStyle(.grouped)
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""
        return "\(short) (\(build))"
    }
}
