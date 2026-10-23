import AppKit
import Sparkle

/// 앱·편집·윈도우 메뉴로 된 메뉴 막대.
enum MainMenu {
    static func install(settingsWindow: SettingsWindowController, updates: UpdateController) {
        let appMenu = NSMenu()
        appMenu.addItem(ActionMenuItem(title: L("menu.about")) { settingsWindow.show(.about) })
        let update = appMenu.addItem(
            withTitle: L("update.check"), action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: "")
        update.target = updates.standardController
        appMenu.addItem(.separator())
        let settings = ActionMenuItem(title: L("menu.settings")) { settingsWindow.show() }
        settings.keyEquivalent = ","
        appMenu.addItem(settings)
        appMenu.addItem(.separator())
        let services = NSMenu()
        appMenu.addItem(withTitle: L("menu.services"), action: nil, keyEquivalent: "").submenu = services
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("menu.hide"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(
            withTitle: L("menu.hideOthers"), action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        ).keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(
            withTitle: L("menu.showAll"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let editMenu = NSMenu(title: L("menu.edit"))
        editMenu.addItem(withTitle: L("menu.undo"), action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: L("menu.cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L("menu.copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L("menu.paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: L("menu.selectAll"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let windowMenu = NSMenu(title: L("menu.window"))
        windowMenu.addItem(
            withTitle: L("menu.minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: L("menu.close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let mainMenu = NSMenu()
        for menu in [appMenu, editMenu, windowMenu] {
            mainMenu.addItem(withTitle: menu.title, action: nil, keyEquivalent: "").submenu = menu
        }
        NSApp.mainMenu = mainMenu
        NSApp.servicesMenu = services
        NSApp.windowsMenu = windowMenu
    }
}
