import CoreGraphics

/// 애니메이션 때문에 줄인 창의 원래 frame 과 줄인 frame.
public struct SavedFrame: Equatable, Sendable {
    /// 두 frame 을 같은 것으로 보는 허용 오차(pt).
    public static let tolerance: CGFloat = 2

    /// 줄이기 전 frame.
    public let original: CGRect
    /// 줄인 뒤 다시 읽은 frame.
    public let shrunk: CGRect?

    /// 원래 frame 과 줄인 뒤 다시 읽은 frame 으로 만든다.
    public init(original: CGRect, shrunk: CGRect?) {
        self.original = original
        self.shrunk = shrunk
    }

    /// 지금 frame 을 원래 frame 으로 되돌릴지 판정한다.
    public func shouldPutBack(current: CGRect) -> Bool {
        guard let shrunk else { return true }
        return Self.isClose(current.width, shrunk.width) && Self.isClose(current.height, shrunk.height)
    }

    /// `frame` 이 이미 원래 frame 이다.
    public func isOriginal(_ frame: CGRect) -> Bool {
        Self.isClose(frame.minX, original.minX) && Self.isClose(frame.minY, original.minY)
            && Self.isClose(frame.width, original.width) && Self.isClose(frame.height, original.height)
    }

    private static func isClose(_ a: CGFloat, _ b: CGFloat) -> Bool {
        abs(a - b) <= tolerance
    }
}
