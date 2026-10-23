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
    private var settingsWindow: SettingsWindowController?
    private var trackerStarted = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let propData = NSAppleEventManager.shared().currentAppleEvent?.paramDescriptor(forKeyword: keyAEPropData)
        let launchedAsLoginItem = propData?.enumCodeValue == keyAELaunchedAsLogInItem
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
        let settingsWindow = SettingsWindowController(
            updater: updates.updater, state: state, settings: settings, loginItems: loginItems, hotKeys: hotKeys)
        self.settingsWindow = settingsWindow
        MainMenu.install(settingsWindow: settingsWindow, updates: updates)
        statusMenu = StatusMenu(
            tracker: tracker, repeater: repeater, hotKeys: hotKeys, state: state, settings: settings,
            loginItems: loginItems, settingsWindow: settingsWindow)

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
        if !launchedAsLoginItem {
            settingsWindow.show()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            settingsWindow?.show()
        }
        return true
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
