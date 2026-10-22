// 앱 아이콘 생성
import AppKit

func draw(_ ctx: CGContext) {
    let rgb = CGColorSpaceCreateDeviceRGB()
    let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)

    // 배경 둥근 사각형 + 아래로 떨어지는 그림자
    let body = CGPath(
        roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 185, cornerHeight: 185,
        transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(gray: 0, alpha: 0.3))
    ctx.addPath(body)
    ctx.setFillColor(CGColor(red: 0.2, green: 0.25, blue: 0.7, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(body)
    ctx.clip()
    let gradient = CGGradient(
        colorsSpace: rgb,
        colors: [
            CGColor(red: 0.36, green: 0.55, blue: 1.0, alpha: 1),
            CGColor(red: 0.22, green: 0.20, blue: 0.68, alpha: 1),
        ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()

    // 창: 흰 본체 + 제목 막대 + 신호등 점
    let window = CGRect(x: 292, y: 520, width: 440, height: 290)
    ctx.addPath(CGPath(roundedRect: window, cornerWidth: 36, cornerHeight: 36, transform: nil))
    ctx.setFillColor(white)
    ctx.fillPath()
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: window, cornerWidth: 36, cornerHeight: 36, transform: nil))
    ctx.clip()
    ctx.setFillColor(CGColor(red: 0.86, green: 0.89, blue: 0.97, alpha: 1))
    ctx.fill(CGRect(x: window.minX, y: window.maxY - 64, width: window.width, height: 64))
    ctx.restoreGState()
    let dots = [
        CGColor(red: 1, green: 0.37, blue: 0.34, alpha: 1),
        CGColor(red: 1, green: 0.74, blue: 0.18, alpha: 1),
        CGColor(red: 0.16, green: 0.79, blue: 0.25, alpha: 1),
    ]
    for (i, color) in dots.enumerated() {
        ctx.setFillColor(color)
        ctx.fillEllipse(in: CGRect(x: window.minX + 30 + CGFloat(i) * 40, y: window.maxY - 46, width: 28, height: 28))
    }

    // 위쪽 화살표: 독에서 창으로
    let arrow = CGMutablePath()
    arrow.move(to: CGPoint(x: 512, y: 500))
    arrow.addLine(to: CGPoint(x: 600, y: 410))
    arrow.addLine(to: CGPoint(x: 548, y: 410))
    arrow.addLine(to: CGPoint(x: 548, y: 318))
    arrow.addLine(to: CGPoint(x: 476, y: 318))
    arrow.addLine(to: CGPoint(x: 476, y: 410))
    arrow.addLine(to: CGPoint(x: 424, y: 410))
    arrow.closeSubpath()
    ctx.addPath(arrow)
    ctx.setFillColor(white)
    ctx.fillPath()

    // 독 막대 + 앱 칸 세 개
    let dock = CGRect(x: 212, y: 186, width: 600, height: 108)
    ctx.addPath(CGPath(roundedRect: dock, cornerWidth: 40, cornerHeight: 40, transform: nil))
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.35))
    ctx.fillPath()
    for i in 0..<3 {
        let tile = CGRect(x: 324 + CGFloat(i) * 136, y: 206, width: 104, height: 68)
        ctx.addPath(CGPath(roundedRect: tile, cornerWidth: 18, cornerHeight: 18, transform: nil))
        ctx.setFillColor(white)
        ctx.fillPath()
    }
}

func png(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    let scale = CGFloat(pixels) / 1024
    ctx.scaleBy(x: scale, y: scale)
    draw(ctx)
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = root.appendingPathComponent("build/AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try png(pixels: size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try png(pixels: size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
exit(iconutil.terminationStatus)
