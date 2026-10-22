import AppKit
import ApplicationServices

/// 앱 구성 요소를 만들어 연결하는 앱 델리게이트.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// AX 요청의 응답 대기 상한.
    private static let axMessagingTimeout: Float = 1.0
    /// 권한 회수·재허용을 확인하는 간격.
    private static let trustPollInterval: TimeInterval = 2

    private var tracker: WindowTracker?
    private var hotKeys: HotKeyCenter?
    private var updates: UpdateController?
    private var statusMenu: StatusMenu?
    private var trackerStarted = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        AXUIElement.systemWide.setMessagingTimeout(Self.axMessagingTimeout)
        let settings = AppSettings(defaults: .standard, domain: Bundle.main.bundleIdentifier ?? "")
        if ApplicationMover.moveIfNeeded(settings: settings) { return }

        let state = AppState()
        let loginItems = LoginItemController()
        let updates = UpdateController(state: state)
        let tracker = WindowTracker(settings: settings)
        let repeater = RepeatController(tracker: tracker, settings: settings)
        let hotKeys = HotKeyCenter(state: state, settings: settings, repeater: repeater)
        self.updates = updates
        self.tracker = tracker
        self.hotKeys = hotKeys
        statusMenu = StatusMenu(
            tracker: tracker, repeater: repeater, hotKeys: hotKeys, state: state, settings: settings,
            loginItems: loginItems, updates: updates)

        hotKeys.install()
        _ = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { hotKeys.update(frontmost: app) }
        }

        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            trustGranted()
        }
        let timer = Timer(timeInterval: Self.trustPollInterval, repeats: true) { _ in
            MainActor.assumeIsolated {
                let trusted = AXIsProcessTrusted()
                hotKeys.update(trusted: trusted)
                if trusted {
                    self.trustGranted()
                } else {
                    self.trustRevoked()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    private func trustGranted() {
        guard !trackerStarted else { return }
        trackerStarted = true
        tracker?.start()
    }

    private func trustRevoked() {
        guard trackerStarted else { return }
        trackerStarted = false
        tracker?.stop()
    }
}
