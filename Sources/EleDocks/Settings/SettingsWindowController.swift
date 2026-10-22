import AppKit
import Sparkle
import SwiftUI

/// 툴바 탭 설정 창.
final class SettingsWindowController {
    private let window: NSWindow
    private let tabs: SettingsTabViewController

    init(
        updater: SPUUpdater?, state: AppState, settings: AppSettings, loginItems: LoginItemController,
        hotKeys: HotKeyCenter
    ) {
        tabs = SettingsTabViewController(hotKeys: hotKeys)
        tabs.tabStyle = .toolbar
        for tab in SettingsTab.allCases {
            let view = tab.view(
                updater: updater, state: state, settings: settings, loginItems: loginItems, hotKeys: hotKeys)
            let host = NSHostingController(rootView: view.tint(Brand.accent))
            host.sizingOptions = .preferredContentSize
            host.title = tab.title
            let item = NSTabViewItem(viewController: host)
            item.label = tab.title
            item.image = tab.image
            item.image?.accessibilityDescription = tab.title
            tabs.addTabViewItem(item)
        }
        window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.center()
        let nc = NotificationCenter.default
        for (name, object) in [
            (NSWindow.willCloseNotification, window), (NSApplication.didResignActiveNotification, nil),
        ] {
            _ = nc.addObserver(forName: name, object: object, queue: .main) { _ in
                MainActor.assumeIsolated { hotKeys.stopRecording() }
            }
        }
    }

    func show(_ tab: SettingsTab? = nil) {
        if let tab, let index = SettingsTab.allCases.firstIndex(of: tab) {
            tabs.selectedTabViewItemIndex = index
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

// 설정 창의 탭 컨트롤러.
private final class SettingsTabViewController: NSTabViewController {
    private let hotKeys: HotKeyCenter

    init(hotKeys: HotKeyCenter) {
        self.hotKeys = hotKeys
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, willSelect: tabViewItem)
        hotKeys.stopRecording()
    }
}

/// 설정 창의 탭.
enum SettingsTab: CaseIterable {
    case general, shortcuts, exclusions, about

    var title: String {
        switch self {
        case .general: L("settings.tab.general")
        case .shortcuts: L("settings.tab.shortcuts")
        case .exclusions: L("settings.tab.exclusions")
        case .about: L("settings.tab.about")
        }
    }

    var image: NSImage {
        switch self {
        case .general: return Brand.tabIcon(symbol: "gearshape")
        case .shortcuts: return Brand.tabIcon(symbol: "keyboard")
        case .exclusions: return Brand.tabIcon(symbol: "nosign")
        case .about:
            let icon = NSApp.applicationIconImage.copy() as? NSImage ?? NSImage()
            icon.size = Brand.tabIconSize
            return icon
        }
    }

    func view(
        updater: SPUUpdater?, state: AppState, settings: AppSettings, loginItems: LoginItemController,
        hotKeys: HotKeyCenter
    ) -> AnyView {
        switch self {
        case .general:
            AnyView(
                GeneralSettingsView(
                    updater: updater, state: state, settings: settings, loginItems: loginItems, hotKeys: hotKeys))
        case .shortcuts: AnyView(ShortcutSettingsView(state: state, settings: settings, hotKeys: hotKeys))
        case .exclusions: AnyView(ExclusionSettingsView(settings: settings, hotKeys: hotKeys))
        case .about: AnyView(AboutSettingsView(updater: updater, state: state))
        }
    }
}
