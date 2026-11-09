import ApplicationServices
import EleDockCore

/// 실행 중인 다른 앱의 메뉴에서 EleDock 단축키와 겹치는 항목을 찾는다.
nonisolated enum MenuShortcutScanner {
    /// 앱 하나의 AX 응답 대기 상한.
    private static let messagingTimeout: Float = 0.5
    /// 내려가는 하위 메뉴 단계 상한.
    private static let maxSubmenuDepth = 3
    private static let itemAttributes = [
        kAXTitleAttribute, "AXIdentifier", kAXMenuItemCmdCharAttribute, kAXMenuItemCmdVirtualKeyAttribute,
        kAXMenuItemCmdModifiersAttribute, kAXChildrenAttribute,
    ]

    /// 스캔할 앱.
    struct App: Sendable {
        let pid: pid_t
        let bundleID: String
    }

    /// 찾을 단축키와 그 표시 문자열.
    struct Target: Sendable {
        let shortcut: Shortcut
        let keyName: String?
        let display: String

        @MainActor init(_ shortcut: Shortcut) {
            self.shortcut = shortcut
            keyName = Shortcut.layoutKeyName(Int(shortcut.keyCode))
            display = shortcut.displayString
        }
    }

    /// 단축키를 쓰는 메뉴 항목 하나.
    struct Conflict: Identifiable, Sendable {
        let bundleID: String
        let display: String
        let item: MenuItemShortcut

        var id: String { bundleID + display }
        /// 행에 보일 단축키와 메뉴 경로.
        var detail: String { "\(display) · \(item.menu) > \(item.title)" }
    }

    /// apps 메뉴에서 targets 단축키를 쓰는 항목.
    static func conflicts(apps: [App], targets: [Target]) -> [Conflict] {
        let menus = apps.map { (app: $0, items: items(pid: $0.pid)) }
        guard !Task.isCancelled else { return [] }
        let titles = MenuItemShortcut.minimizeTitles(in: menus.flatMap(\.items))
        return menus.flatMap { menu in
            targets.compactMap { target in
                target.shortcut.conflict(in: menu.items, keyName: target.keyName, minimizeTitles: titles).map {
                    Conflict(bundleID: menu.app.bundleID, display: target.display, item: $0)
                }
            }
        }
    }

    // pid 앱의 메뉴 항목.
    private static func items(pid: pid_t) -> [MenuItemShortcut] {
        let app = AXUIElement.application(pid: pid)
        var items: [MenuItemShortcut] = []
        do throws(AccessibilityError) {
            guard let bar = try read(app, { () throws(AccessibilityError) in try app.attribute(kAXMenuBarAttribute) })
            else { return [] }
            try collect(bar as! AXUIElement, menu: nil, depth: 0, into: &items)
        } catch {
            return []
        }
        return items
    }

    private static func collect(
        _ parent: AXUIElement, menu: String?, depth: Int, into items: inout [MenuItemShortcut]
    ) throws(AccessibilityError) {
        let children = try read(parent, { () throws(AccessibilityError) in try parent.attribute(kAXChildrenAttribute) })
        for element in children as? [AXUIElement] ?? [] {
            guard !Task.isCancelled else { return }
            guard
                let values = try read(
                    element,
                    { () throws(AccessibilityError) in
                        try element.attributes(itemAttributes)
                    }), values.count == itemAttributes.count
            else { continue }
            let title = values[0] as? String ?? ""
            if let menu {
                items.append(
                    MenuItemShortcut(
                        menu: menu, title: title, identifier: values[1] as? String, character: values[2] as? String,
                        virtualKey: values[3] as? Int, modifiers: values[4] as? Int ?? 0))
            }
            if menu == nil || depth < maxSubmenuDepth, let submenu = (values[5] as? [AXUIElement])?.first {
                try collect(submenu, menu: menu ?? title, depth: menu == nil ? depth : depth + 1, into: &items)
            }
        }
    }

    // timeout 을 걸고 AX 값을 읽는다.
    private static func read<T>(_ element: AXUIElement, _ body: () throws(AccessibilityError) -> T?)
        throws(AccessibilityError) -> T?
    {
        do throws(AccessibilityError) {
            return try element.withMessagingTimeout(messagingTimeout, body)
        } catch {
            if error.isDelay { throw error }
            return nil
        }
    }
}
