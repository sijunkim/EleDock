import AppKit
import SwiftUI

/// 제외 앱 섹션: 최소화에서 건너뛸 앱 목록.
struct ExclusionSettingsView: View {
    @ObservedObject var settings: AppSettings
    let hotKeys: HotKeyCenter
    @StateObject private var model = ExclusionSettingsModel()

    var body: some View {
        Form {
            Section {
                List(settings.excludedBundleIDs, id: \.self, selection: $model.selection) { bundleID in
                    AppRow(bundleID: bundleID)
                }
                .frame(height: SettingsLayout.exclusionListHeight)
                .overlay {
                    if settings.excludedBundleIDs.isEmpty {
                        ExclusionsEmptyView()
                    }
                }
                .onDeleteCommand(perform: removeSelected)
                HStack(spacing: SettingsLayout.exclusionButtonSpacing) {
                    AddAppButton(makeMenu: addMenu)
                        .fixedSize()
                        .help(L("exclusions.add"))
                    Button(action: removeSelected) {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(model.selection == nil)
                    .help(L("exclusions.remove"))
                    .accessibilityLabel(L("exclusions.remove"))
                    Spacer()
                }
            } footer: {
                SectionFooter(L("exclusions.help"))
            }
        }
        .formStyle(.grouped)
    }

    private func removeSelected() {
        if let selection = model.selection {
            settings.removeExcluded(selection)
            hotKeys.update()
        }
        model.selection = nil
    }

    // 실행 중인 앱으로 추가 메뉴를 만든다.
    private func addMenu() -> NSMenu {
        let menu = NSMenu()
        for app in runningApps() {
            menu.addItem(
                ActionMenuItem(title: app.localizedName ?? app.bundleIdentifier ?? "") { add(app.bundleIdentifier) })
        }
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem(title: L("exclusions.choose")) { chooseApps() })
        return menu
    }

    private func runningApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter {
                $0.activationPolicy == .regular && $0.processIdentifier != getpid()
                    && $0.bundleIdentifier.map { !settings.isExcluded($0) } == true
            }
            .sorted { ($0.localizedName ?? "").localizedStandardCompare($1.localizedName ?? "") == .orderedAscending }
    }

    private func add(_ bundleID: String?) {
        guard let bundleID else { return }
        if settings.addExcluded(bundleID) { hotKeys.update() }
    }

    private func chooseApps() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            add(Bundle(url: url)?.bundleIdentifier)
        }
    }
}

/// 앱 아이콘과 이름 행.
struct AppRow: View {
    let bundleID: String
    var detail: String?

    var body: some View {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        HStack {
            Image(
                nsImage: url.map { NSWorkspace.shared.icon(forFile: $0.path) }
                    ?? NSWorkspace.shared.icon(for: .applicationBundle)
            )
            .resizable()
            .frame(width: SettingsLayout.appIconSize, height: SettingsLayout.appIconSize)
            Text(url.map { FileManager.default.displayName(atPath: $0.path) } ?? bundleID)
            if let detail {
                Text(detail).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }
}

private final class ExclusionSettingsModel: ObservableObject {
    @Published var selection: String?
}
