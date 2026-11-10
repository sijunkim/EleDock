import AppKit
import EleDockCore

/// 응용 프로그램 폴더로 옮기고 재실행한다.
enum ApplicationMover {
    /// 기존 인스턴스 종료를 기다리는 횟수.
    private static let terminateWaitSteps = 30
    private static let terminateWaitStep: TimeInterval = 0.1
    private static let quarantineAttribute = "com.apple.quarantine"

    /// 응용 프로그램 폴더에 설치되는 번들 이름.
    static let installedName =
        (Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String
            ?? ProcessInfo.processInfo.processName) + ".app"

    // 정규 설치 경로로 옮겨 재실행한다.
    static func moveIfNeeded(settings: AppSettings) -> Bool {
        let source = AppTranslocation.originalBundleURL()
        let installPaths = [
            URL(fileURLWithPath: "/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
        ].map { $0.appendingPathComponent(installedName) }
        guard
            needsMove(
                path: source.path, installPaths: installPaths.map(\.path),
                sameFilePaths: sameFilePaths(as: source, in: installPaths))
        else {
            removeInstalls(otherThan: source, in: installPaths)
            return false
        }
        guard !settings.suppressMoveAlert, confirmMove(settings: settings) else { return false }
        guard let dest = install(at: installPaths) else {
            showFailure()
            return false
        }
        removeInstalls(otherThan: dest, in: installPaths)
        return relaunch(at: dest, removing: source)
    }

    // 번들과 같은 파일인 정규 설치 경로를 찾는다.
    private static func sameFilePaths(as bundle: URL, in installPaths: [URL]) -> Set<String> {
        guard let bundleID = fileID(bundle) else { return [] }
        return Set(installPaths.filter { fileID($0)?.isEqual(bundleID) == true }.map(\.path))
    }

    // 남길 설치본 말고 정규 설치 경로에 있는 설치본을 끝내고 휴지통으로 옮긴다.
    private static func removeInstalls(otherThan kept: URL, in installPaths: [URL]) {
        let others = otherInstallPaths(
            installPaths.map(\.path), keeping: kept.path, sameFilePaths: sameFilePaths(as: kept, in: installPaths))
        for path in others where FileManager.default.fileExists(atPath: path) {
            let install = URL(fileURLWithPath: path)
            terminateRunningInstance(at: install)
            try? FileManager.default.trashItem(at: install, resultingItemURL: nil)
        }
    }

    private static func fileID(_ url: URL) -> (any NSCopying & NSSecureCoding & NSObjectProtocol)? {
        try? url.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier
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

    // 실행 중인 번들을 정규 설치 경로에 설치한다.
    private static func install(at installPaths: [URL]) -> URL? {
        let fm = FileManager.default
        for target in installPaths {
            let dir = target.deletingLastPathComponent()
            let temp = dir.appendingPathComponent(".EleDock-\(UUID().uuidString).app")
            let existed = fm.fileExists(atPath: target.path)
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                try fm.copyItem(at: Bundle.main.bundleURL, to: temp)
                if existed { terminateRunningInstance(at: target) }
                let installed = try fm.replaceItemAt(target, withItemAt: temp, options: .usingNewMetadataOnly) ?? target
                removeQuarantine(in: installed)
                return installed
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
