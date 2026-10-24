import AppKit
import EleDocksCore

/// 설치에 쓴 디스크 이미지를 꺼내고 휴지통으로 옮긴다.
enum InstallerCleanup {
    private static let hdiutil = URL(fileURLWithPath: "/usr/bin/hdiutil")

    // 설치 디스크 정리를 묻는다.
    static func offerIfNeeded() {
        let mounts = installerMounts()
        let runningPath = AppTranslocation.originalBundleURL().path
        guard !mounts.isEmpty, !mounts.contains(where: { $0.contains(path: runningPath) }) else { return }
        confirmAndClean(mounts)
    }

    // 설치 디스크를 찾는다.
    private static func installerMounts() -> [DiskImageMount] {
        let process = Process()
        process.executableURL = hdiutil
        process.arguments = ["info", "-plist"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
            let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [] }
        let bundleName = Bundle.main.bundleURL.lastPathComponent
        return DiskImageMount.list(hdiutilInfo: info).filter { mount in
            FileManager.default.fileExists(atPath: mount.mountPoint + "/" + bundleName)
        }
    }

    // 정리 방법을 묻고 실행한다.
    private static func confirmAndClean(_ mounts: [DiskImageMount]) {
        let alert = NSAlert()
        alert.messageText = L("cleanup.title")
        alert.informativeText = L("cleanup.message")
        alert.addButton(withTitle: L("cleanup.ejectAndTrash"))
        alert.addButton(withTitle: L("cleanup.eject"))
        alert.addButton(withTitle: L("cleanup.keep")).keyEquivalent = "\u{1b}"
        alert.window.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn || response == .alertSecondButtonReturn else { return }
        for mount in mounts {
            do {
                try NSWorkspace.shared.unmountAndEjectDevice(at: URL(fileURLWithPath: mount.mountPoint))
            } catch {
                NSAlert(error: error).runModal()
                continue
            }
            if response == .alertFirstButtonReturn {
                try? FileManager.default.trashItem(at: URL(fileURLWithPath: mount.imagePath), resultingItemURL: nil)
            }
        }
    }
}
