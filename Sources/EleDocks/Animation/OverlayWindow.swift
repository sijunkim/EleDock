import AppKit
import EleDocksCore
import QuartzCore

/// 창 스냅숏을 실어 키프레임대로 움직이는 투명 창.
final class OverlayWindow {
    private let window: NSWindow
    private let imageLayer = CALayer()
    /// 창 content 좌표로 바꾼 키프레임.
    private let frames: [CGRect]
    private(set) var isClosed = false

    /// AX 좌표 키프레임으로 만든다.
    init(image: CGImage, frames: [CGRect]) {
        let height = DockLocator.primaryScreenHeight
        let flipped = frames.map { FrameInterpolation.flipped($0, primaryScreenHeight: height) }
        let bounds = (flipped.dropFirst().reduce(flipped.first ?? .zero) { $0.union($1) }).integral
        self.frames = flipped.map { $0.offsetBy(dx: -bounds.minX, dy: -bounds.minY) }

        window = NSWindow(contentRect: bounds, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.sharingType = .none
        window.animationBehavior = .none
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) - 1)
        window.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenAuxiliary]

        let view = NSView(frame: CGRect(origin: .zero, size: bounds.size))
        view.wantsLayer = true
        window.contentView = view
        imageLayer.contents = image
        imageLayer.contentsGravity = .resize
        imageLayer.contentsScale = window.backingScaleFactor
        place(at: self.frames.first ?? .zero, opacity: 1)
        view.layer?.addSublayer(imageLayer)
    }

    /// 첫 키프레임 자리에 `opacity` 로 띄운다.
    func show(opacity: Float) {
        guard !isClosed else { return }
        place(at: frames.first ?? .zero, opacity: opacity)
        window.orderFrontRegardless()
        CATransaction.flush()
    }

    /// 키프레임을 `duration` 초에 걸쳐 재생한다.
    func animate(
        duration: Double, opacity: (Double) -> Double, completion: @escaping @MainActor @Sendable () -> Void
    ) {
        guard !isClosed else { return }
        guard let last = frames.last else { return completion() }
        let times = AnimationTiming.sampleTimes(count: frames.count)
        let keyTimes = times.map { NSNumber(value: $0) }
        func keyframes(_ keyPath: String, _ values: [Any]) -> CAKeyframeAnimation {
            let animation = CAKeyframeAnimation(keyPath: keyPath)
            animation.values = values
            animation.keyTimes = keyTimes
            animation.duration = duration
            animation.calculationMode = .linear
            return animation
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.isClosed else { return }
                completion()
            }
        }
        place(at: last, opacity: Float(opacity(1)))
        imageLayer.add(
            keyframes("position", frames.map { NSValue(point: CGPoint(x: $0.midX, y: $0.midY)) }), forKey: "position")
        imageLayer.add(keyframes("bounds.size", frames.map { NSValue(size: $0.size) }), forKey: "size")
        imageLayer.add(keyframes("opacity", times.map { NSNumber(value: opacity($0)) }), forKey: "opacity")
        CATransaction.commit()
    }

    /// `delay` 초 뒤 `duration` 초 동안 사라지고 닫는다.
    func fadeOut(after delay: Double, duration: Double, completion: @escaping @MainActor @Sendable () -> Void) {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !self.isClosed else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            CATransaction.setCompletionBlock { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, !self.isClosed else { return }
                    self.close()
                    completion()
                }
            }
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = imageLayer.opacity
            fade.toValue = 0
            fade.duration = duration
            imageLayer.opacity = 0
            imageLayer.add(fade, forKey: "fadeOut")
            CATransaction.commit()
        }
    }

    /// 애니메이션을 멈추고 화면에서 내린다.
    func close() {
        guard !isClosed else { return }
        isClosed = true
        imageLayer.removeAllAnimations()
        window.orderOut(nil)
    }

    private func place(at frame: CGRect, opacity: Float) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.bounds = CGRect(origin: .zero, size: frame.size)
        imageLayer.position = CGPoint(x: frame.midX, y: frame.midY)
        imageLayer.opacity = opacity
        CATransaction.commit()
    }
}
