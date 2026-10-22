import AppKit
import ApplicationServices
import Sparkle

/// 메뉴바 아이콘과 메뉴.
final class StatusMenu: NSObject, NSMenuDelegate {
    /// 메뉴에 보여 줄 최소화 창 수 상한.
    private static let minimizedItemLimit = 20
    private static let iconSize = NSSize(width: 16, height: 16)
    /// 메뉴바 심볼 크기.
    private static let statusSymbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
    private static let accessibilitySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")

    private let statusItem: NSStatusItem
    private let tracker: WindowTracker
    private let repeater: RepeatController
    private let hotKeys: HotKeyCenter
    private let state: AppState
    private let settings: AppSettings
    private let loginItems: LoginItemController
    private let updates: UpdateController
    private var settingsWindow: SettingsWindowController?

    init(
        tracker: WindowTracker, repeater: RepeatController, hotKeys: HotKeyCenter, state: AppState,
        settings: AppSettings, loginItems: LoginItemController, updates: UpdateController
    ) {
        self.tracker = tracker
        self.repeater = repeater
        self.hotKeys = hotKeys
        self.state = state
        self.settings = settings
        self.loginItems = loginItems
        self.updates = updates
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let image = NSImage(systemSymbolName: "dock.arrow.up.rectangle", accessibilityDescription: "EleDocks")?
            .withSymbolConfiguration(Self.statusSymbolConfiguration)
        {
            image.isTemplate = true
            statusItem.button?.image = image
        } else {
            statusItem.button?.title = "EleDocks"
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        addMinimizedWindowItems(to: menu)
        menu.addItem(.separator())
        if AXIsProcessTrusted() {
            menu.addItem(NSMenuItem(title: L("menu.permission.granted"), action: nil, keyEquivalent: ""))
        } else {
            menu.addItem(NSMenuItem(title: L("menu.permission.required"), action: nil, keyEquivalent: ""))
            menu.addItem(
                NSMenuItem(
                    title: L("menu.permission.open"), action: #selector(openAccessibilitySettings), keyEquivalent: ""))
        }
        menu.addItem(.separator())
        loginItems.refresh()
        let login = NSMenuItem(
            title: loginItems.label(L("login"), approval: L("login.approval")), action: #selector(toggleLoginItem),
            keyEquivalent: "")
        login.state = loginItems.isEnabled ? .on : .off
        menu.addItem(login)
        let hotKeysItem = NSMenuItem(title: L("hotkeys.enabled"), action: #selector(toggleHotKeys), keyEquivalent: "")
        hotKeysItem.state = settings.hotKeysEnabled ? .on : .off
        menu.addItem(hotKeysItem)
        if !state.failedHotKeys.isEmpty {
            menu.addItem(NSMenuItem(title: L("hotkeys.failed"), action: nil, keyEquivalent: ""))
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L("menu.about"), action: #selector(showAbout), keyEquivalent: ""))
        let update = NSMenuItem(
            title: L("update.check"), action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: "")
        update.target = updates.standardController
        menu.addItem(update)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L("menu.settings"), action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(title: L("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        for item in menu.items where item.target == nil && item.action != #selector(NSApplication.terminate(_:)) {
            item.target = self
        }
    }

    // 추적 중인 최소화 창을 최근 순으로 메뉴에 넣는다.
    private func addMinimizedWindowItems(to menu: NSMenu) {
        let items = tracker.minimizedItems(limit: Self.minimizedItemLimit)
        guard !items.isEmpty else {
            menu.addItem(NSMenuItem(title: L("menu.windows.none"), action: nil, keyEquivalent: ""))
            return
        }
        for item in items {
            let menuItem = NSMenuItem(title: item.title, action: #selector(restoreWindow(_:)), keyEquivalent: "")
            menuItem.representedObject = item.window
            if let icon = NSRunningApplication(processIdentifier: item.pid)?.icon?.copy() as? NSImage {
                icon.size = Self.iconSize
                menuItem.image = icon
            }
            menu.addItem(menuItem)
        }
        menu.addItem(
            NSMenuItem(title: L("menu.windows.restoreAll"), action: #selector(restoreAllWindows), keyEquivalent: ""))
    }

    @objc private func restoreWindow(_ sender: NSMenuItem) {
        guard let object = sender.representedObject, CFGetTypeID(object as CFTypeRef) == AXUIElementGetTypeID() else {
            return
        }
        repeater.stop()
        tracker.restore(window: object as! AXUIElement)
    }

    @objc private func restoreAllWindows() {
        repeater.restoreAll()
    }

    @objc private func toggleHotKeys() {
        hotKeys.setEnabled(!settings.hotKeysEnabled)
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(
                updater: updates.updater, state: state, settings: settings, loginItems: loginItems, hotKeys: hotKeys)
        }
        settingsWindow?.show()
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func openAccessibilitySettings() {
        guard let url = Self.accessibilitySettingsURL else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func toggleLoginItem() {
        loginItems.toggle()
    }
}
