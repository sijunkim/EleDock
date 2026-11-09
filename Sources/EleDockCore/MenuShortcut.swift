import Foundation

/// 다른 앱 메뉴 항목 하나의 제목과 단축키.
public struct MenuItemShortcut: Equatable, Sendable {
    /// 최소화 메뉴 항목의 AXIdentifier.
    static let minimizeIdentifier = "performMiniaturize:"

    /// 최상위 메뉴 제목.
    public var menu: String
    /// 항목 제목.
    public var title: String
    /// AXIdentifier.
    public var identifier: String?
    /// kAXMenuItemCmdCharAttribute.
    public var character: String?
    /// kAXMenuItemCmdVirtualKeyAttribute.
    public var virtualKey: Int?
    /// kAXMenuItemCmdModifiersAttribute.
    public var modifiers: Int

    /// AX 속성 값으로 만든다.
    public init(
        menu: String, title: String, identifier: String?, character: String?, virtualKey: Int?, modifiers: Int
    ) {
        self.menu = menu
        self.title = title
        self.identifier = identifier
        self.character = character
        self.virtualKey = virtualKey
        self.modifiers = modifiers
    }

    /// 최소화 항목으로 볼 소문자 제목.
    public static func minimizeTitles(in items: [MenuItemShortcut]) -> Set<String> {
        Set(items.filter { $0.identifier == minimizeIdentifier }.map { $0.title.lowercased() })
    }

    func isMinimize(titles: Set<String>) -> Bool {
        let title = title.lowercased()
        return identifier == Self.minimizeIdentifier || title == "minimize" || titles.contains(title)
    }
}

extension Shortcut {
    /// AX 메뉴 수식키 마스크(kAXMenuItemModifier*).
    public var menuModifiers: Int {
        var mask = 0
        if modifiers & CarbonModifier.shift != 0 { mask |= MenuModifier.shift }
        if modifiers & CarbonModifier.option != 0 { mask |= MenuModifier.option }
        if modifiers & CarbonModifier.control != 0 { mask |= MenuModifier.control }
        if modifiers & CarbonModifier.cmd == 0 { mask |= MenuModifier.noCommand }
        return mask
    }

    /// 이 단축키를 쓰는 첫 메뉴 항목.
    public func conflict(in items: [MenuItemShortcut], keyName: String?, minimizeTitles: Set<String>)
        -> MenuItemShortcut?
    {
        items.first { isUsed(by: $0, keyName: keyName) && !$0.isMinimize(titles: minimizeTitles) }
    }

    func isUsed(by item: MenuItemShortcut, keyName: String?) -> Bool {
        guard item.modifiers == menuModifiers else { return false }
        if let virtualKey = item.virtualKey { return virtualKey == Int(keyCode) }
        guard let keyName, let character = item.character else { return false }
        return character.caseInsensitiveCompare(keyName) == .orderedSame
    }
}

/// AX 메뉴 수식키 마스크(kAXMenuItemModifier*).
enum MenuModifier {
    static let shift = 1 << 0
    static let option = 1 << 1
    static let control = 1 << 2
    static let noCommand = 1 << 3
}
