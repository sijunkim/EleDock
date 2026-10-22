import EleDocksCore
import SwiftUI

/// 단축키 탭의 "이 단축키를 쓰는 앱" 목록.
final class MenuConflictsModel: ObservableObject {
    @Published private(set) var conflicts: [MenuShortcutScanner.Conflict] = []
    @Published private(set) var isScanning = false
    private let settings: AppSettings
    private var task: Task<Void, Never>?

    init(settings: AppSettings) {
        self.settings = settings
    }

    /// 실행 중인 앱을 다시 스캔한다.
    func scan() {
        task?.cancel()
        var seen: Set<String> = []
        let apps = NSWorkspace.shared.runningApplications.compactMap { app -> MenuShortcutScanner.App? in
            guard app.activationPolicy == .regular, app.processIdentifier != getpid(),
                let bundleID = app.bundleIdentifier, seen.insert(bundleID).inserted
            else { return nil }
            return MenuShortcutScanner.App(pid: app.processIdentifier, bundleID: bundleID)
        }
        let targets = Shortcut.Kind.allCases.map { MenuShortcutScanner.Target(settings.shortcut($0)) }
        conflicts = []
        isScanning = true
        task = Task.detached { [weak self] in
            let found = MenuShortcutScanner.conflicts(apps: apps, targets: targets)
            await MainActor.run {
                guard !Task.isCancelled, let self else { return }
                self.conflicts = found
                self.isScanning = false
            }
        }
    }
}

/// "이 단축키를 쓰는 앱" 섹션.
struct MenuConflictsSection: View {
    @ObservedObject var model: MenuConflictsModel
    @ObservedObject var settings: AppSettings

    var body: some View {
        Section {
            List(model.conflicts) { conflict in
                AppRow(bundleID: conflict.bundleID, detail: conflict.detail)
            }
            .frame(height: SettingsLayout.conflictListHeight)
            .overlay {
                if model.isScanning {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text(L("shortcut.conflicts.scanning"))
                    }
                    .foregroundStyle(.secondary)
                } else if model.conflicts.isEmpty {
                    Text(L("shortcut.conflicts.none")).foregroundStyle(.secondary)
                }
            }
            .onChange(of: Shortcut.Kind.allCases.map(settings.shortcut)) { _ in model.scan() }
        } header: {
            Text(L("shortcut.conflicts"))
        }
        .onAppear { model.scan() }
    }
}
