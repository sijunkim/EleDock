// DMG 창 배경 이미지 생성
import AppKit

let canvas = CGSize(width: 660, height: 400)
let brandTop = CGColor(red: 0.36, green: 0.55, blue: 1.0, alpha: 1)
let brandBottom = CGColor(red: 0.22, green: 0.20, blue: 0.68, alpha: 1)
let iconCenterY: CGFloat = 400 - 210
let appIconX: CGFloat = 170
let applicationsX: CGFloat = 490

func line(_ text: String, _ attributes: [NSAttributedString.Key: Any]) -> CTLine {
    CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
}

func width(_ line: CTLine) -> CGFloat {
    CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
}

func draw(_ ctx: CGContext) {
    let rgb = CGColorSpaceCreateDeviceRGB()

    // 아주 옅은 브랜드 색 배경
    let background = CGGradient(
        colorsSpace: rgb,
        colors: [
            CGColor(red: 0.99, green: 0.99, blue: 1.0, alpha: 1),
            CGColor(red: 0.93, green: 0.94, blue: 0.99, alpha: 1),
        ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(
        background, start: CGPoint(x: 0, y: canvas.height), end: .zero, options: [])
    let glow = CGGradient(
        colorsSpace: rgb,
        colors: [
            CGColor(red: 0.36, green: 0.55, blue: 1.0, alpha: 0.08),
            CGColor(red: 0.36, green: 0.55, blue: 1.0, alpha: 0),
        ] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(
        glow, startCenter: CGPoint(x: canvas.width / 2, y: iconCenterY), startRadius: 0,
        endCenter: CGPoint(x: canvas.width / 2, y: iconCenterY), endRadius: 300, options: [])

    // 워드마크: 그라데이션 세리프 이탤릭 "Ele" + "Docks"
    let eleFont = NSFont.systemFont(ofSize: 34, weight: .semibold).fontDescriptor
        .withDesign(.serif)
        .map { NSFont(descriptor: $0.withSymbolicTraits(.italic), size: 34)! }!
    let ele = line("Ele", [.font: eleFont])
    let docks = line(
        "Docks",
        [
            .font: NSFont.systemFont(ofSize: 30, weight: .semibold),
            .foregroundColor: NSColor(white: 0.12, alpha: 1),
        ])
    let baseline: CGFloat = 400 - 78
    let eleX = (canvas.width - width(ele) - width(docks)) / 2
    ctx.textMatrix = .identity
    ctx.saveGState()
    ctx.setTextDrawingMode(.clip)
    ctx.textPosition = CGPoint(x: eleX, y: baseline)
    CTLineDraw(ele, ctx)
    let markGradient = CGGradient(colorsSpace: rgb, colors: [brandTop, brandBottom] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(
        markGradient, start: CGPoint(x: 0, y: baseline + eleFont.ascender),
        end: CGPoint(x: 0, y: baseline + eleFont.descender), options: [])
    ctx.restoreGState()
    ctx.textPosition = CGPoint(x: eleX + width(ele), y: baseline)
    CTLineDraw(docks, ctx)

    // 부제: 넓은 자간 회색 대문자
    let tagline = line(
        "ELEGANCE + DOCK",
        [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor(white: 0.55, alpha: 1),
            .kern: 3.5,
        ])
    ctx.textPosition = CGPoint(x: (canvas.width - width(tagline) + 3.5) / 2, y: 400 - 102)
    CTLineDraw(tagline, ctx)

    // 앱에서 Applications 로 향하는 점선 곡선 화살표
    let start = CGPoint(x: appIconX + 92, y: iconCenterY)
    let end = CGPoint(x: applicationsX - 96, y: iconCenterY)
    let arrow = CGMutablePath()
    arrow.move(to: start)
    arrow.addQuadCurve(to: end, control: CGPoint(x: canvas.width / 2, y: iconCenterY + 34))
    ctx.saveGState()
    ctx.addPath(arrow)
    ctx.setLineWidth(3)
    ctx.setLineCap(.round)
    ctx.setLineDash(phase: 0, lengths: [0.1, 9])
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    ctx.drawLinearGradient(
        markGradient, start: CGPoint(x: start.x - 4, y: 0), end: CGPoint(x: end.x, y: 0), options: [])
    ctx.restoreGState()

    let head = CGMutablePath()
    head.move(to: CGPoint(x: end.x - 11, y: end.y + 11))
    head.addLine(to: end)
    head.addLine(to: CGPoint(x: end.x - 14, y: end.y - 6))
    ctx.addPath(head)
    ctx.setStrokeColor(brandBottom)
    ctx.setLineWidth(3)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()
}

func png(scale: CGFloat) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(canvas.width * scale), pixelsHigh: Int(canvas.height * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = canvas
    draw(NSGraphicsContext(bitmapImageRep: rep)!.cgContext)
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let buildDir = root.appendingPathComponent("build")
try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)
let normal = buildDir.appendingPathComponent("dmg-background.png")
let retina = buildDir.appendingPathComponent("dmg-background@2x.png")
try png(scale: 1).write(to: normal)
try png(scale: 2).write(to: retina)

let tiffutil = Process()
tiffutil.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil")
let output = root.appendingPathComponent("Resources/dmg-background.tiff")
tiffutil.arguments = ["-cathidpicheck", normal.path, retina.path, "-out", output.path]
try tiffutil.run()
tiffutil.waitUntilExit()
exit(tiffutil.terminationStatus)
