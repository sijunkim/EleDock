import AppKit
import Combine
import Sparkle
import SwiftUI

/// 사이드바로 섹션을 고르는 설정 창.
final class SettingsWindowController: NSObject, NSToolbarDelegate {
    private let window: NSWindow
    private let navigation: SettingsNavigation
    private var titleObservation: AnyCancellable?

    init(
        updater: SPUUpdater?, state: AppState, settings: AppSettings, loginItems: LoginItemController,
        hotKeys: HotKeyCenter
    ) {
        let navigation = SettingsNavigation()
        let sidebar = NSHostingController(rootView: SettingsSidebar(navigation: navigation))
        let detail = NSHostingController(
            rootView: SettingsDetail(
                navigation: navigation, updater: updater, state: state, settings: settings, loginItems: loginItems,
                hotKeys: hotKeys
            )
            .tint(Brand.accent))
        sidebar.sizingOptions = []
        detail.sizingOptions = []
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
        sidebarItem.canCollapse = false
        sidebarItem.minimumThickness = SettingsLayout.sidebarWidth
        sidebarItem.maximumThickness = SettingsLayout.sidebarWidth
        let split = NSSplitViewController()
        split.addSplitViewItem(sidebarItem)
        split.addSplitViewItem(NSSplitViewItem(viewController: detail))
        self.navigation = navigation
        window = NSWindow(contentViewController: split)
        super.init()
        window.isReleasedWhenClosed = false
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        let toolbar = NSToolbar()
        toolbar.delegate = self
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        window.setContentSize(
            NSSize(width: SettingsLayout.sidebarWidth + SettingsLayout.detailWidth, height: SettingsLayout.height))
        window.center()
        titleObservation = navigation.$section.sink { [split] in split.title = $0.title }
        _ = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: window, queue: .main
        ) { _ in
            MainActor.assumeIsolated { hotKeys.stopRecording() }
        }
    }

    func show(_ section: SettingsSection? = nil) {
        if let section {
            navigation.section = section
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.sidebarTrackingSeparator]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.sidebarTrackingSeparator]
    }
}

/// 설정 창의 섹션.
enum SettingsSection: CaseIterable {
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
        case .general: return Brand.sidebarIcon(symbol: "gearshape")
        case .shortcuts: return Brand.sidebarIcon(symbol: "keyboard")
        case .exclusions: return Brand.sidebarIcon(symbol: "nosign")
        case .about:
            let icon = NSApp.applicationIconImage.copy() as? NSImage ?? NSImage()
            icon.size = Brand.sidebarIconSize
            return icon
        }
    }
}

// 설정 창에서 고른 섹션.
private final class SettingsNavigation: ObservableObject {
    @Published var section = SettingsSection.general
}

// 섹션 목록 사이드바.
private struct SettingsSidebar: View {
    @ObservedObject var navigation: SettingsNavigation

    var body: some View {
        List(
            SettingsSection.allCases, id: \.self,
            selection: Binding(
                get: { navigation.section },
                set: { if let section = $0 { navigation.section = section } })
        ) { section in
            Label {
                Text(section.title)
            } icon: {
                Image(nsImage: section.image)
            }
        }
        .listStyle(.sidebar)
    }
}

// 고른 섹션의 설정 화면.
private struct SettingsDetail: View {
    @ObservedObject var navigation: SettingsNavigation
    let updater: SPUUpdater?
    let state: AppState
    let settings: AppSettings
    let loginItems: LoginItemController
    let hotKeys: HotKeyCenter

    var body: some View {
        switch navigation.section {
        case .general: GeneralSettingsView(updater: updater, settings: settings, loginItems: loginItems)
        case .shortcuts: ShortcutSettingsView(state: state, settings: settings, hotKeys: hotKeys)
        case .exclusions: ExclusionSettingsView(settings: settings)
        case .about: AboutSettingsView(updater: updater, state: state)
        }
    }
}
