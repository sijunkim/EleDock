import CoreGraphics

/// 화면 캡처 목록(SCWindow)에서 읽은 창 하나.
public struct WindowCandidate: Sendable {
    /// 창을 가진 앱의 pid.
    public let pid: Int32
    /// 창 frame(왼쪽 위 원점).
    public let frame: CGRect
    /// 창 제목.
    public let title: String?
    /// 창 레이어.
    public let layer: Int

    /// 소유 pid·frame·제목·레이어로 만든다.
    public init(pid: Int32, frame: CGRect, title: String?, layer: Int) {
        self.pid = pid
        self.frame = frame
        self.title = title
        self.layer = layer
    }
}

/// AX 창과 캡처 목록의 창을 짝짓는다.
public enum WindowMatching {
    /// 같은 창으로 보는 frame 허용 오차.
    public static let frameTolerance: CGFloat = 1

    /// 맞는 후보의 위치.
    public static func bestMatch(pid: Int32, frame: CGRect, title: String?, candidates: [WindowCandidate]) -> Int? {
        let matches = candidates.indices.filter {
            let candidate = candidates[$0]
            return candidate.pid == pid && candidate.layer == 0 && isClose(candidate.frame, frame)
        }
        if matches.count == 1 { return matches[0] }
        guard let title else { return nil }
        let titled = matches.filter { candidates[$0].title == title }
        return titled.count == 1 ? titled[0] : nil
    }

    private static func isClose(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= frameTolerance && abs(a.minY - b.minY) <= frameTolerance
            && abs(a.width - b.width) <= frameTolerance && abs(a.height - b.height) <= frameTolerance
    }
}
