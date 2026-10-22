import AppKit
import ApplicationServices
import EleDocksCore

/// Dock 프로세스의 AX 트리와 `com.apple.dock` 설정으로 DockLayout 을 만든다.
enum DockLocator {
    /// Dock AX 조회 timeout.
    private static let timeout: Float = 0.05
    private static let bundleID = "com.apple.dock"

    private static let subroleKinds: [String: DockItemInfo.Kind] = [
        "AXApplicationDockItem": .application,
        "AXMinimizedWindowDockItem": .minimizedWindow,
        "AXSeparatorDockItem": .separator,
    ]

    /// 지금 Dock 상태.
    static func layout() -> DockLayout {
        CFPreferencesAppSynchronize(bundleID as CFString)
        let autohide = preference("autohide") as? Bool ?? false
        let list = autohide ? nil : dockList()
        let items = list.map(items(in:)) ?? []
        let listFrame = list.flatMap { list in
            try? list.withMessagingTimeout(timeout) { () throws(AccessibilityError) in try list.frame }
        }
        let screen =
            listFrame.flatMap { ScreenGeometry.screen(containing: CGPoint(x: $0.midX, y: $0.midY), in: screenFrames) }
            ?? mainScreenFrame
        let orientation = DockGeometry.orientation(
            stored: preference("orientation") as? String, items: items, screen: screen)
        return DockLayout(
            items: items, orientation: orientation, screen: screen,
            minimizeToApplication: preference("minimize-to-application") as? Bool ?? false, isHidden: autohide)
    }

    /// 주 화면 높이.
    static var primaryScreenHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    /// `rect` 와 가장 많이 겹치는 화면.
    static func screenFrame(for rect: CGRect) -> CGRect? {
        ScreenGeometry.screen(for: rect, in: screenFrames)
    }

    // 지금 작업 중인 화면.
    private static var mainScreenFrame: CGRect {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return .zero }
        return FrameInterpolation.flipped(screen.frame, primaryScreenHeight: primaryScreenHeight)
    }

    private static var screenFrames: [CGRect] {
        let height = primaryScreenHeight
        return NSScreen.screens.map { FrameInterpolation.flipped($0.frame, primaryScreenHeight: height) }
    }

    private static func preference(_ key: String) -> Any? {
        CFPreferencesCopyAppValue(key as CFString, bundleID as CFString)
    }

    private static func dockList() -> AXUIElement? {
        guard
            let pid = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.processIdentifier
        else { return nil }
        let dock = AXUIElement.application(pid: pid)
        let children = attribute(dock, kAXChildrenAttribute) as? [AXUIElement] ?? []
        return children.first { attribute($0, kAXRoleAttribute) as? String == kAXListRole }
    }

    // Dock 목록의 항목을 읽는다.
    private static func items(in list: AXUIElement) -> [DockItemInfo] {
        let children = attribute(list, kAXChildrenAttribute) as? [AXUIElement] ?? []
        let names = [kAXSubroleAttribute, kAXTitleAttribute, kAXPositionAttribute, kAXSizeAttribute]
        return children.compactMap { child in
            let values = try? child.withMessagingTimeout(timeout) { () throws(AccessibilityError) in
                try child.attributes(names)
            }
            guard let values, values.count == names.count,
                let origin = try? CGPoint(axValue: values[2]), let size = try? CGSize(axValue: values[3])
            else { return nil }
            let kind = (values[0] as? String).flatMap { subroleKinds[$0] } ?? .other
            return DockItemInfo(kind: kind, title: values[1] as? String, frame: CGRect(origin: origin, size: size))
        }
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        (try? element.withMessagingTimeout(timeout) { () throws(AccessibilityError) in try element.attribute(name) })
            ?? nil
    }
}
