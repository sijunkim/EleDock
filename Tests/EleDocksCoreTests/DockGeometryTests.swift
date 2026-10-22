import CoreGraphics
import Testing

@testable import EleDocksCore

struct DockGeometryTests {
    private static let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    private static func tile(_ kind: DockItemInfo.Kind, _ title: String?, x: CGFloat, width: CGFloat = 50)
        -> DockItemInfo
    {
        DockItemInfo(kind: kind, title: title, frame: CGRect(x: x, y: 850, width: width, height: 50))
    }

    private static func verticalTile(_ kind: DockItemInfo.Kind, _ title: String?, x: CGFloat, y: CGFloat)
        -> DockItemInfo
    {
        DockItemInfo(kind: kind, title: title, frame: CGRect(x: x, y: y, width: 50, height: 50))
    }

    private static let apps = [tile(.application, "Finder", x: 500), tile(.application, "Safari", x: 550)]
    private static let separator = tile(.separator, nil, x: 600, width: 10)
    private static let trash = tile(.other, "Trash", x: 610)

    private static func layout(_ items: [DockItemInfo], orientation: DockOrientation = .bottom, toApp: Bool = false)
        -> DockLayout
    {
        DockLayout(items: items, orientation: orientation, screen: screen, minimizeToApplication: toApp)
    }

    // MARK: 방향

    @Test(arguments: [("bottom", DockOrientation.bottom), ("left", .left), ("right", .right)])
    func storedOrientationWins(stored: String, expected: DockOrientation) {
        #expect(DockGeometry.orientation(stored: stored, items: Self.apps, screen: Self.screen) == expected)
    }

    @Test func horizontalItemsMeanBottom() {
        #expect(DockGeometry.orientation(stored: nil, items: Self.apps, screen: Self.screen) == .bottom)
        #expect(DockGeometry.orientation(stored: "top", items: Self.apps, screen: Self.screen) == .bottom)
    }

    @Test func verticalItemsUseScreenSide() {
        let left = [
            Self.verticalTile(.application, "A", x: 0, y: 300), Self.verticalTile(.application, "B", x: 0, y: 350),
        ]
        let right = [
            Self.verticalTile(.application, "A", x: 1390, y: 300),
            Self.verticalTile(.application, "B", x: 1390, y: 350),
        ]
        #expect(DockGeometry.orientation(stored: nil, items: left, screen: Self.screen) == .left)
        #expect(DockGeometry.orientation(stored: nil, items: right, screen: Self.screen) == .right)
    }

    @Test func singleItemUsesNearestEdge() {
        let leftOnly = [Self.verticalTile(.application, "A", x: 0, y: 400)]
        #expect(DockGeometry.orientation(stored: nil, items: leftOnly, screen: Self.screen) == .left)
        #expect(DockGeometry.orientation(stored: nil, items: [Self.apps[0]], screen: Self.screen) == .bottom)
    }

    @Test func noItemsMeanBottom() {
        #expect(DockGeometry.orientation(stored: nil, items: [], screen: Self.screen) == .bottom)
    }

    // MARK: 가장자리 폴백

    @Test(arguments: [
        (DockOrientation.bottom, CGRect(x: 696, y: 852, width: 48, height: 48)),
        (.left, CGRect(x: 0, y: 426, width: 48, height: 48)),
        (.right, CGRect(x: 1392, y: 426, width: 48, height: 48)),
    ])
    func edgeFallbackIsCenteredOnDockEdge(orientation: DockOrientation, expected: CGRect) {
        #expect(DockGeometry.edgeFallback(Self.layout([], orientation: orientation)) == expected)
    }

    @Test func emptyItemsFallBackToEdge() {
        let layout = Self.layout([])
        #expect(
            DockGeometry.minimizeDestination(in: layout, appName: "Safari", pendingCount: 0)
                == DockGeometry.edgeFallback(layout))
        #expect(
            DockGeometry.restoreSource(in: layout, windowTitle: "a", appName: "Safari")
                == DockGeometry.edgeFallback(layout))
    }

    // MARK: 최소화 목적지

    @Test func withoutMinimizedTilesTakesItemAfterLastSeparator() {
        let layout = Self.layout(Self.apps + [Self.separator, Self.trash])
        #expect(DockGeometry.minimizeDestination(in: layout, appName: nil, pendingCount: 0) == Self.trash.frame)
        #expect(
            DockGeometry.minimizeDestination(in: layout, appName: nil, pendingCount: 2)
                == CGRect(x: 710, y: 850, width: 50, height: 50))
    }

    @Test func separatorAtEndUsesTileSizeNotSeparatorSize() {
        let layout = Self.layout(Self.apps + [Self.separator])
        #expect(
            DockGeometry.minimizeDestination(in: layout, appName: nil, pendingCount: 0)
                == CGRect(x: 610, y: 850, width: 50, height: 50))
        #expect(
            DockGeometry.minimizeDestination(in: layout, appName: nil, pendingCount: 1)
                == CGRect(x: 660, y: 850, width: 50, height: 50))
    }

    @Test func noSeparatorFallsBackToEdge() {
        let layout = Self.layout(Self.apps)
        #expect(
            DockGeometry.minimizeDestination(in: layout, appName: nil, pendingCount: 0)
                == DockGeometry.edgeFallback(layout))
    }

    @Test func withMinimizedTilesTakesNextSlotPlusPending() {
        let minimized = [Self.tile(.minimizedWindow, "a", x: 610), Self.tile(.minimizedWindow, "b", x: 660)]
        let layout = Self.layout(Self.apps + [Self.separator] + minimized + [Self.tile(.other, "Trash", x: 710)])
        #expect(
            DockGeometry.minimizeDestination(in: layout, appName: nil, pendingCount: 0)
                == CGRect(x: 710, y: 850, width: 50, height: 50))
        #expect(
            DockGeometry.minimizeDestination(in: layout, appName: nil, pendingCount: 3)
                == CGRect(x: 860, y: 850, width: 50, height: 50))
    }

    @Test func verticalDockMovesDownward() {
        let items = [
            Self.verticalTile(.application, "A", x: 0, y: 300),
            DockItemInfo(kind: .separator, title: nil, frame: CGRect(x: 0, y: 350, width: 50, height: 10)),
            Self.verticalTile(.minimizedWindow, "a", x: 0, y: 360),
        ]
        let layout = Self.layout(items, orientation: .left)
        #expect(
            DockGeometry.minimizeDestination(in: layout, appName: nil, pendingCount: 1)
                == CGRect(x: 0, y: 460, width: 50, height: 50))
    }

    @Test func minimizeToApplicationUsesAppTile() {
        let layout = Self.layout(Self.apps + [Self.separator, Self.trash], toApp: true)
        #expect(DockGeometry.minimizeDestination(in: layout, appName: "Safari", pendingCount: 4) == Self.apps[1].frame)
        #expect(
            DockGeometry.minimizeDestination(in: layout, appName: "Xcode", pendingCount: 0)
                == DockGeometry.edgeFallback(layout))
        #expect(
            DockGeometry.minimizeDestination(in: layout, appName: nil, pendingCount: 0)
                == DockGeometry.edgeFallback(layout))
        #expect(DockGeometry.restoreSource(in: layout, windowTitle: "a", appName: "Finder") == Self.apps[0].frame)
    }

    // MARK: 복원 출발점

    @Test func restoreSourceMatchesTitle() {
        let minimized = [Self.tile(.minimizedWindow, "a", x: 610), Self.tile(.minimizedWindow, "b", x: 660)]
        let layout = Self.layout(Self.apps + [Self.separator] + minimized)
        #expect(DockGeometry.restoreSource(in: layout, windowTitle: "a", appName: nil) == minimized[0].frame)
    }

    @Test func restoreSourceWithDuplicateTitlesTakesLast() {
        let minimized = [
            Self.tile(.minimizedWindow, "a", x: 610), Self.tile(.minimizedWindow, "a", x: 660),
            Self.tile(.minimizedWindow, "b", x: 710),
        ]
        let layout = Self.layout(Self.apps + [Self.separator] + minimized)
        #expect(DockGeometry.restoreSource(in: layout, windowTitle: "a", appName: nil) == minimized[1].frame)
    }

    @Test func restoreSourceWithoutTitleMatchTakesLastMinimizedTile() {
        let minimized = [Self.tile(.minimizedWindow, "a", x: 610), Self.tile(.minimizedWindow, "b", x: 660)]
        let layout = Self.layout(Self.apps + [Self.separator] + minimized)
        #expect(DockGeometry.restoreSource(in: layout, windowTitle: "zzz", appName: nil) == minimized[1].frame)
        #expect(DockGeometry.restoreSource(in: layout, windowTitle: nil, appName: nil) == minimized[1].frame)
    }

    @Test func restoreSourceWithoutMinimizedTilesUsesMinimizeDestination() {
        let layout = Self.layout(Self.apps + [Self.separator, Self.trash])
        #expect(DockGeometry.restoreSource(in: layout, windowTitle: "a", appName: nil) == Self.trash.frame)
    }

    // MARK: 실제 창 축소 frame

    @Test func shrinkTargetIsTargetWhenDockShown() {
        let target = CGRect(x: 696, y: 856, width: 48, height: 36)
        #expect(DockGeometry.shrinkTarget(target, in: Self.layout([])) == target)
    }

    @Test func shrinkTargetIsBelowScreenWhenDockHidden() {
        var layout = Self.layout([])
        layout.isHidden = true
        let target = CGRect(x: 696, y: 856, width: 48, height: 36)
        #expect(DockGeometry.shrinkTarget(target, in: layout) == CGRect(x: 696, y: 900, width: 48, height: 36))
    }
}
