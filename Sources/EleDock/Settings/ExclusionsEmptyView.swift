import SwiftUI

/// 제외 앱 목록이 비었을 때의 Dock 그림과 안내 문구.
struct ExclusionsEmptyView: View {
    private static let windowDash = StrokeStyle(lineWidth: 1.5, dash: [4, 3])
    private static let arrowStroke = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
    private static let lineOpacity = 0.45
    private static let dockOpacity = 0.12
    private static let tileOpacity = 0.3

    var body: some View {
        VStack(spacing: SettingsLayout.emptySpacing) {
            ZStack {
                DockArt(part: .window).stroke(Brand.accent.opacity(Self.lineOpacity), style: Self.windowDash)
                DockArt(part: .lights).fill(Brand.accent.opacity(Self.lineOpacity))
                DockArt(part: .arrow).stroke(Brand.accent.opacity(Self.lineOpacity), style: Self.arrowStroke)
                DockArt(part: .dock).fill(Brand.accent.opacity(Self.dockOpacity))
                DockArt(part: .tiles).fill(Brand.accent.opacity(Self.tileOpacity))
            }
            .frame(width: DockArt.size.width, height: DockArt.size.height)
            VStack(spacing: SettingsLayout.emptyTextSpacing) {
                Text(L("exclusions.empty"))
                Text(L("exclusions.empty.detail")).font(.caption)
            }
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }
}

// 점선 창, 아래 화살표, Dock 막대와 타일.
nonisolated private struct DockArt: Shape {
    enum Part { case window, lights, arrow, dock, tiles }

    static let size = CGSize(width: 150, height: 78)
    private static let window = CGRect(x: 39, y: 2, width: 72, height: 40)
    private static let windowRadius: CGFloat = 6
    private static let lightCount = 3
    private static let lightDiameter: CGFloat = 5
    private static let lightPitch: CGFloat = 8
    private static let lightInset: CGFloat = 7
    private static let arrowTop: CGFloat = 46
    private static let arrowBottom: CGFloat = 56
    private static let arrowHead: CGFloat = 4
    private static let dock = CGRect(x: 15, y: 60, width: 120, height: 16)
    private static let dockRadius: CGFloat = 6
    private static let tileCount = 3
    private static let tile = CGSize(width: 14, height: 10)
    private static let tileGap: CGFloat = 4
    private static let tileRadius: CGFloat = 3

    let part: Part

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch part {
        case .window:
            path.addRoundedRect(
                in: Self.window, cornerSize: CGSize(width: Self.windowRadius, height: Self.windowRadius))
        case .lights:
            for i in 0..<Self.lightCount {
                path.addEllipse(
                    in: CGRect(
                        x: Self.window.minX + Self.lightInset - Self.lightDiameter / 2 + CGFloat(i) * Self.lightPitch,
                        y: Self.window.minY + Self.lightInset - Self.lightDiameter / 2,
                        width: Self.lightDiameter, height: Self.lightDiameter))
            }
        case .arrow:
            let x = Self.window.midX
            path.move(to: CGPoint(x: x, y: Self.arrowTop))
            path.addLine(to: CGPoint(x: x, y: Self.arrowBottom))
            path.move(to: CGPoint(x: x - Self.arrowHead, y: Self.arrowBottom - Self.arrowHead))
            path.addLine(to: CGPoint(x: x, y: Self.arrowBottom))
            path.addLine(to: CGPoint(x: x + Self.arrowHead, y: Self.arrowBottom - Self.arrowHead))
        case .dock:
            path.addRoundedRect(in: Self.dock, cornerSize: CGSize(width: Self.dockRadius, height: Self.dockRadius))
        case .tiles:
            let width = CGFloat(Self.tileCount) * (Self.tile.width + Self.tileGap) - Self.tileGap
            for i in 0..<Self.tileCount {
                let origin = CGPoint(
                    x: Self.dock.midX - width / 2 + CGFloat(i) * (Self.tile.width + Self.tileGap),
                    y: Self.dock.midY - Self.tile.height / 2)
                path.addRoundedRect(
                    in: CGRect(origin: origin, size: Self.tile),
                    cornerSize: CGSize(width: Self.tileRadius, height: Self.tileRadius))
            }
        }
        return path.applying(
            CGAffineTransform(translationX: rect.minX, y: rect.minY)
                .scaledBy(x: rect.width / Self.size.width, y: rect.height / Self.size.height))
    }
}
