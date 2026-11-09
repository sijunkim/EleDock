import AppKit
import SwiftUI

/// 앱 추가 메뉴를 띄우는 "+" 버튼.
struct AddAppButton: NSViewRepresentable {
    let makeMenu: () -> NSMenu

    func makeNSView(context: Context) -> MenuButton { MenuButton() }

    func updateNSView(_ button: MenuButton, context: Context) {
        button.makeMenu = makeMenu
    }
}

/// makeMenu 로 만든 메뉴를 자기 아래에 띄우는 버튼.
final class MenuButton: NSButton {
    /// 버튼과 띄운 메뉴 사이 간격.
    private static let menuGap: CGFloat = 4

    var makeMenu: (() -> NSMenu)?

    init() {
        super.init(frame: .zero)
        image = NSImage(systemSymbolName: "plus", accessibilityDescription: L("exclusions.add"))
        isBordered = false
        setAccessibilityLabel(L("exclusions.add"))
        toolTip = L("exclusions.add")
        target = self
        action = #selector(showMenu)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    @objc private func showMenu() {
        let y = isFlipped ? bounds.maxY + Self.menuGap : bounds.minY - Self.menuGap
        makeMenu?().popUp(positioning: nil, at: NSPoint(x: 0, y: y), in: self)
    }
}

/// 클로저를 메인 액터에서 실행하는 메뉴 항목.
nonisolated final class ActionMenuItem: NSMenuItem {
    private let handler: @MainActor () -> Void

    init(title: String, handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func run() {
        let handler = handler
        MainActor.assumeIsolated { handler() }
    }
}
