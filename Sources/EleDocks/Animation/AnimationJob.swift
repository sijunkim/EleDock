import ApplicationServices
import CoreGraphics
import EleDocksCore

/// 창 하나에 진행 중인 최소화·복원 애니메이션.
final class AnimationJob {
    enum Kind {
        case minimize, restore
    }

    /// 작업 단계.
    enum Stage {
        /// 스냅숏을 기다린다.
        case capturing
        /// kAXMinimized 를 보내기 전이다.
        case preparing
        /// kAXMinimized 를 보냈다.
        case sending
        /// kAXMinimized 가 성공했다.
        case minimized
        /// 복원 애니메이션 중이다.
        case restoring
        /// 복원 애니메이션이 끝나 frame 되돌리기·페이드만 남았다.
        case settling
        case cancelled
    }

    /// 지금까지 만든 작업 수.
    private static var createdCount = 0

    let kind: Kind
    /// 작업 순번.
    let order: Int
    let window: AXUIElement
    /// 창을 가진 앱의 pid.
    let pid: pid_t
    var stage: Stage
    var overlay: OverlayWindow?
    /// kAXMinimized 를 보내며 메인 스레드를 막을 수 있는 남은 시간.
    var blocking = AXBlockingBudget(seconds: AnimationTiming.minimizeBlockingLimit)

    init(kind: Kind, window: AXUIElement, pid: pid_t, overlay: OverlayWindow? = nil) {
        self.kind = kind
        self.window = window
        self.pid = pid
        self.overlay = overlay
        stage = kind == .minimize ? .capturing : .restoring
        Self.createdCount += 1
        order = Self.createdCount
    }
}

extension AnimationJob {
    var isCancelled: Bool { stage == .cancelled }

    /// 아직 kAXMinimized 를 보내지 않은 최소화 작업이다.
    var isUnsentMinimize: Bool { stage == .capturing || stage == .preparing }

    /// 창에 kAXMinimized 를 보낸다.
    func sendMinimize(yield: () async -> Bool) async -> Bool {
        for attempt in 0...AnimationTiming.minimizeRetries {
            if attempt > 0 { try? await Task.sleep(for: .seconds(AnimationTiming.minimizeRetryInterval)) }
            guard !isCancelled else { return false }
            stage = .sending
            do {
                try blocking.run(window, timeout: WindowTracker.callTimeout) { () throws(AccessibilityError) in
                    try window.setMinimized(true)
                }
                return true
            } catch .cannotComplete {
                guard !blocking.isExhausted else { return false }
                guard await yield() else { return false }
                if (try? blocking.run(window, timeout: WindowTracker.callTimeout, { window.minimizedState })) == true {
                    return true
                }
            } catch {
                return false
            }
        }
        return false
    }
}

extension Collection<AnimationJob> {
    /// 진행 중인 작업들로 정한 새 최소화 요청의 처리 방법.
    var minimizeAdmission: MinimizeAdmission {
        let minimizing = filter { $0.kind == .minimize }
        return AnimationAdmission.minimize(
            activeJobs: count, pendingCaptures: minimizing.filter { $0.stage == .capturing }.count,
            queuedMinimizes: minimizing.filter { $0.stage != .minimized }.count)
    }
}

/// 복원 애니메이션에 쓸 최소화 직전 스냅숏.
struct SnapshotCache {
    /// 보관하는 스냅숏 수.
    static let capacity = 20
    /// 보관할 때 줄이는 긴 변 픽셀 수.
    static let maximumPixelLength: CGFloat = 1024

    private var cache = RecentCache<AXUIElement, (pid: pid_t, image: CGImage)>(capacity: capacity)

    func image(for window: AXUIElement) -> CGImage? {
        cache.value(for: window)?.image
    }

    /// 스냅숏을 줄여서 가장 최근 것으로 넣는다.
    mutating func insert(_ image: CGImage, for window: AXUIElement, pid: pid_t) {
        cache.insert((pid, Self.downscaled(image)), for: window)
    }

    mutating func remove(_ window: AXUIElement) {
        cache.remove(window)
    }

    /// 종료된 앱의 스냅숏을 모두 버린다.
    mutating func removeAll(pid: pid_t) {
        cache.removeAll { $1.pid == pid }
    }

    private static func downscaled(_ image: CGImage) -> CGImage {
        let size = FrameInterpolation.downscaled(
            CGSize(width: image.width, height: image.height), maxLength: maximumPixelLength)
        let width = Int(size.width)
        let height = Int(size.height)
        guard width < image.width || height < image.height, width > 0, height > 0,
            let space = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return image }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return context.makeImage() ?? image
    }
}
