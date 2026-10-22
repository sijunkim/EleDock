import CoreGraphics
import EleDocksCore
@preconcurrency import ScreenCaptureKit

/// ScreenCaptureKit 으로 창 하나의 스냅숏을 찍는다.
@available(macOS 14, *)
enum WindowSnapshotter {
    /// `timeout` 안에서 창 스냅숏을 찍는다.
    static func capture(pid: pid_t, frame: CGRect, title: String?, timeout: Double) async -> CGImage? {
        await withCheckedContinuation { continuation in
            let race = FirstResult(continuation)
            let work = Task { race.resume(await capture(pid: pid, frame: frame, title: title)) }
            let timer = Task {
                try? await Task.sleep(for: .seconds(timeout))
                work.cancel()
                race.resume(nil)
            }
            Task {
                _ = await work.value
                timer.cancel()
            }
        }
    }

    /// AX 창(pid·frame·제목)과 짝지어지는 창을 찍는다.
    static func capture(pid: pid_t, frame: CGRect, title: String?) async -> CGImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            let windows = content.windows
            let candidates = windows.map {
                WindowCandidate(
                    pid: $0.owningApplication?.processID ?? -1, frame: $0.frame, title: $0.title, layer: $0.windowLayer)
            }
            guard let index = WindowMatching.bestMatch(pid: pid, frame: frame, title: title, candidates: candidates)
            else { return nil }
            let filter = SCContentFilter(desktopIndependentWindow: windows[index])
            let scale = CGFloat(filter.pointPixelScale)
            let configuration = SCStreamConfiguration()
            configuration.width = Int((filter.contentRect.width * scale).rounded())
            configuration.height = Int((filter.contentRect.height * scale).rounded())
            configuration.showsCursor = false
            configuration.ignoreShadowsSingleWindow = true
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        } catch {
            return nil
        }
    }
}

/// continuation 을 재개한다.
private final class FirstResult {
    private var continuation: CheckedContinuation<CGImage?, Never>?

    init(_ continuation: CheckedContinuation<CGImage?, Never>) {
        self.continuation = continuation
    }

    func resume(_ image: CGImage?) {
        continuation?.resume(returning: image)
        continuation = nil
    }
}
