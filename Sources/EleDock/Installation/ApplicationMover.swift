import AppKit
import EleDockCore

/// 응용 프로그램 폴더로 옮기고 재실행한다.
enum ApplicationMover {
    /// 기존 인스턴스 종료를 기다리는 횟수.
    private static let terminateWaitSteps = 30
    private static let terminateWaitStep: TimeInterval = 0.1
    private static let quarantineAttribute = "com.apple.quarantine"

    // 응용 프로그램 폴더로 옮겨 재실행한다.
    static func moveIfNeeded(settings: AppSettings) -> Bool {
        let source = AppTranslocation.originalBundleURL()
        guard location(of: source).needsMove, !settings.suppressMoveAlert, confirmMove(settings: settings) else {
            return false
        }
        guard let dest = copyToApplications() else {
            showFailure()
            return false
        }
        return relaunch(at: dest, removing: source)
    }

    private static var bundleName: String { Bundle.main.bundleURL.lastPathComponent }

    private static var applicationDirectories: [URL] {
        [
            URL(fileURLWithPath: "/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
        ]
    }

    // 번들 위치를 분류한다.
    private static func location(of source: URL) -> InstallLocation {
        let sourceID = try? source.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier
        let isSameFile = applicationDirectories.contains { dir in
            guard let sourceID,
                let id = try? dir.appendingPathComponent(bundleName).resourceValues(forKeys: [
                    .fileResourceIdentifierKey
                ]).fileResourceIdentifier
            else { return false }
            return sourceID.isEqual(id)
        }
        return InstallLocation(path: source.path, homeDirectory: NSHomeDirectory(), isSameFileAsInstalled: isSameFile)
    }

    // 응용 프로그램 폴더로 옮길지 묻는다.
    private static func confirmMove(settings: AppSettings) -> Bool {
        let alert = NSAlert()
        alert.messageText = L("move.title")
        alert.informativeText = L("move.message")
        alert.addButton(withTitle: L("move.confirm"))
        alert.addButton(withTitle: L("move.later"))
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = L("move.suppress")
        alert.window.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if alert.suppressionButton?.state == .on {
            settings.suppressMoveAlert = true
        }
        return response == .alertFirstButtonReturn
    }

    // 실행 중인 번들을 응용 프로그램 폴더로 복사한다.
    private static func copyToApplications() -> URL? {
        let fm = FileManager.default
        for dir in applicationDirectories {
            let target = dir.appendingPathComponent(bundleName)
            let temp = dir.appendingPathComponent(".EleDock-\(UUID().uuidString).app")
            let existed = fm.fileExists(atPath: target.path)
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                try fm.copyItem(at: Bundle.main.bundleURL, to: temp)
                if existed {
                    terminateRunningInstance(at: target)
                    try fm.trashItem(at: target, resultingItemURL: nil)
                }
                try fm.moveItem(at: temp, to: target)
                removeQuarantine(in: target)
                return target
            } catch {
                try? fm.removeItem(at: temp)
                if existed { return nil }
            }
        }
        return nil
    }

    // 번들의 격리 속성을 지운다.
    private static func removeQuarantine(in bundle: URL) {
        removexattr(bundle.path, quarantineAttribute, XATTR_NOFOLLOW)
        guard let items = FileManager.default.enumerator(at: bundle, includingPropertiesForKeys: nil) else { return }
        for case let url as URL in items {
            removexattr(url.path, quarantineAttribute, XATTR_NOFOLLOW)
        }
    }

    private static func relaunch(at dest: URL, removing source: URL) -> Bool {
        guard Relauncher.openAfterExit(dest) else { return false }
        try? FileManager.default.trashItem(at: source, resultingItemURL: nil)
        NSApp.terminate(nil)
        return true
    }

    private static func showFailure() {
        let failure = NSAlert()
        failure.messageText = L("move.failed")
        failure.informativeText = L("move.failed.info")
        failure.window.level = .floating
        failure.runModal()
    }

    // 대상 위치에서 이미 실행 중인 인스턴스를 끝낸다.
    private static func terminateRunningInstance(at target: URL) {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let resolved = target.standardizedFileURL.resolvingSymlinksInPath()
        for other in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        where other.processIdentifier != getpid()
            && other.bundleURL?.standardizedFileURL.resolvingSymlinksInPath() == resolved
        {
            let pid = other.processIdentifier
            other.terminate()
            for _ in 0..<terminateWaitSteps where kill(pid, 0) == 0 { Thread.sleep(forTimeInterval: terminateWaitStep) }
            if kill(pid, 0) == 0 { other.forceTerminate() }
        }
    }
}
