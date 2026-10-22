import CoreGraphics

/// Dock 이 붙은 화면 가장자리.
public enum DockOrientation: String, Sendable {
    /// 아래.
    case bottom
    /// 왼쪽.
    case left
    /// 오른쪽.
    case right
}

/// Dock AX 트리에서 읽은 항목 하나.
public struct DockItemInfo: Equatable, Sendable {
    /// 항목 종류.
    public enum Kind: Sendable {
        /// 앱 아이콘(`AXApplicationDockItem`).
        case application
        /// 최소화된 창 타일(`AXMinimizedWindowDockItem`).
        case minimizedWindow
        /// 구분선(`AXSeparatorDockItem`).
        case separator
        /// 그 밖의 항목(폴더·휴지통 등).
        case other
    }

    /// 항목 종류.
    public let kind: Kind
    /// AX 제목.
    public let title: String?
    /// 항목의 AX 좌표 frame.
    public let frame: CGRect

    /// 종류·제목·AX 좌표 frame 으로 만든다.
    public init(kind: Kind, title: String?, frame: CGRect) {
        self.kind = kind
        self.title = title
        self.frame = frame
    }
}

/// 목적지·출발점 계산에 쓰는 Dock 상태.
public struct DockLayout: Equatable, Sendable {
    /// Dock 순서대로의 항목.
    public var items: [DockItemInfo]
    /// Dock 이 붙은 가장자리.
    public var orientation: DockOrientation
    /// Dock 이 있는 화면의 AX 좌표 frame.
    public var screen: CGRect
    /// `com.apple.dock` 의 `minimize-to-application`.
    public var minimizeToApplication: Bool
    /// `com.apple.dock` 의 `autohide`.
    public var isHidden: Bool

    /// 항목·방향·화면·앱 아이콘으로 최소화 여부·자동 숨김으로 만든다.
    public init(
        items: [DockItemInfo], orientation: DockOrientation, screen: CGRect, minimizeToApplication: Bool,
        isHidden: Bool = false
    ) {
        self.items = items
        self.orientation = orientation
        self.screen = screen
        self.minimizeToApplication = minimizeToApplication
        self.isHidden = isHidden
    }
}

/// Dock 항목 배치로 최소화 목적지와 복원 출발점을 구한다.
public enum DockGeometry {
    /// 화면 가장자리 대체 타일의 한 변.
    public static let fallbackTileLength: CGFloat = 48

    /// Dock 이 붙은 가장자리를 정한다.
    public static func orientation(stored: String?, items: [DockItemInfo], screen: CGRect) -> DockOrientation {
        if let stored, let value = DockOrientation(rawValue: stored) { return value }
        let centers = items.map { CGPoint(x: $0.frame.midX, y: $0.frame.midY) }
        guard let first = centers.first else { return .bottom }
        let xs = centers.map(\.x)
        let ys = centers.map(\.y)
        let xSpread = (xs.max() ?? first.x) - (xs.min() ?? first.x)
        let ySpread = (ys.max() ?? first.y) - (ys.min() ?? first.y)
        if ySpread > xSpread { return first.x < screen.midX ? .left : .right }
        if xSpread > ySpread { return .bottom }
        let distances: [(DockOrientation, CGFloat)] = [
            (.bottom, screen.maxY - first.y), (.left, first.x - screen.minX), (.right, screen.maxX - first.x),
        ]
        return distances.min { $0.1 < $1.1 }?.0 ?? .bottom
    }

    /// Dock 쪽 화면 가장자리 중앙의 `fallbackTileLength` 정사각형.
    public static func edgeFallback(_ layout: DockLayout) -> CGRect {
        let side = fallbackTileLength
        let screen = layout.screen
        switch layout.orientation {
        case .bottom: return CGRect(x: screen.midX - side / 2, y: screen.maxY - side, width: side, height: side)
        case .left: return CGRect(x: screen.minX, y: screen.midY - side / 2, width: side, height: side)
        case .right: return CGRect(x: screen.maxX - side, y: screen.midY - side / 2, width: side, height: side)
        }
    }

    /// 최소화한 창이 들어갈 Dock 칸.
    public static func minimizeDestination(in layout: DockLayout, appName: String?, pendingCount: Int) -> CGRect {
        if layout.minimizeToApplication {
            return applicationTile(in: layout, appName: appName) ?? edgeFallback(layout)
        }
        let items = layout.items
        if let last = items.last(where: { $0.kind == .minimizedWindow }) {
            return slot(after: last.frame, offset: 1 + pendingCount, orientation: layout.orientation)
        }
        guard let separator = items.lastIndex(where: { $0.kind == .separator }) else { return edgeFallback(layout) }
        let next = items.index(after: separator)
        if next < items.endIndex {
            return slot(after: items[next].frame, offset: pendingCount, orientation: layout.orientation)
        }
        guard let tile = items.last(where: { $0.kind != .separator })?.frame else { return edgeFallback(layout) }
        let line = items[separator].frame
        let first: CGRect
        switch layout.orientation {
        case .bottom: first = CGRect(x: line.maxX, y: tile.minY, width: tile.width, height: tile.height)
        case .left, .right: first = CGRect(x: tile.minX, y: line.maxY, width: tile.width, height: tile.height)
        }
        return slot(after: first, offset: pendingCount, orientation: layout.orientation)
    }

    /// 복원할 창이 나올 Dock 칸.
    public static func restoreSource(in layout: DockLayout, windowTitle: String?, appName: String?) -> CGRect {
        if layout.minimizeToApplication {
            return applicationTile(in: layout, appName: appName) ?? edgeFallback(layout)
        }
        let minimized = layout.items.filter { $0.kind == .minimizedWindow }
        if let windowTitle, let match = minimized.last(where: { $0.title == windowTitle }) { return match.frame }
        if let last = minimized.last { return last.frame }
        return minimizeDestination(in: layout, appName: appName, pendingCount: 0)
    }

    /// 실제 창을 줄여 둘 frame.
    public static func shrinkTarget(_ target: CGRect, in layout: DockLayout) -> CGRect {
        guard layout.isHidden else { return target }
        return CGRect(x: target.minX, y: layout.screen.maxY, width: target.width, height: target.height)
    }

    private static func applicationTile(in layout: DockLayout, appName: String?) -> CGRect? {
        guard let appName else { return nil }
        return layout.items.first { $0.kind == .application && $0.title == appName }?.frame
    }

    // `tile` 에서 Dock 진행 방향으로 `offset` 칸 옮긴 칸.
    private static func slot(after tile: CGRect, offset: Int, orientation: DockOrientation) -> CGRect {
        let steps = CGFloat(offset)
        switch orientation {
        case .bottom: return tile.offsetBy(dx: tile.width * steps, dy: 0)
        case .left, .right: return tile.offsetBy(dx: 0, dy: tile.height * steps)
        }
    }
}
