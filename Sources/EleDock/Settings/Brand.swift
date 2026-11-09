import AppKit
import SwiftUI

/// 앱 아이콘의 브랜드 색과 그 색으로 그린 사이드바 아이콘.
nonisolated enum Brand {
    static let gradientTop = NSColor(deviceRed: 0.36, green: 0.55, blue: 1.0, alpha: 1)
    static let gradientBottom = NSColor(deviceRed: 0.22, green: 0.20, blue: 0.68, alpha: 1)
    static let accent = Color(.sRGB, red: 0x3F / 255.0, green: 0x52 / 255.0, blue: 0xC8 / 255.0)
    static let sidebarIconSize = NSSize(width: 24, height: 24)
    /// 타일 바깥 여백(아이콘 한 변 대비).
    private static let tileInsetRatio: CGFloat = 100.0 / 1024
    /// 타일 모서리 반지름(타일 한 변 대비).
    private static let tileCornerRatio: CGFloat = 185.0 / 824
    /// 심볼 크기(타일 한 변 대비).
    private static let symbolRatio: CGFloat = 0.5
    /// 아이콘 그라데이션 방향(위에서 아래).
    private static let gradientAngle: CGFloat = -90

    /// 브랜드 그라데이션 타일 위에 흰 심볼을 얹은 사이드바 아이콘.
    static func sidebarIcon(symbol: String) -> NSImage {
        NSImage(size: sidebarIconSize, flipped: false) { rect in
            let tile = rect.insetBy(dx: rect.width * tileInsetRatio, dy: rect.height * tileInsetRatio)
            let radius = tile.width * tileCornerRatio
            NSGradient(starting: gradientTop, ending: gradientBottom)?
                .draw(in: NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius), angle: gradientAngle)
            let configuration = NSImage.SymbolConfiguration(pointSize: tile.height * symbolRatio, weight: .medium)
                .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
            guard
                let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
                    .withSymbolConfiguration(configuration)
            else { return true }
            let size = image.size
            image.draw(
                in: NSRect(
                    x: tile.midX - size.width / 2, y: tile.midY - size.height / 2, width: size.width,
                    height: size.height))
            return true
        }
    }
}
