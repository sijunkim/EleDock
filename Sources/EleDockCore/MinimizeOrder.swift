/// 최소화 후보 앱을 고르고 순서를 정한다.
public enum MinimizeOrder {
    /// 최소화 후보 앱인지 판정한다.
    public static func isCandidate(isRegular: Bool, isExcluded: Bool) -> Bool {
        isRegular && !isExcluded
    }

    /// 화면 앞→뒤 순서의 후보 앱 pid 목록.
    public static func pids(zOrder: [Int32], frontmost: Int32?, isCandidate: (Int32) -> Bool) -> [Int32] {
        var seen: Set<Int32> = []
        var result: [Int32] = []
        for pid in zOrder {
            guard seen.insert(pid).inserted, isCandidate(pid) else { continue }
            result.append(pid)
        }
        if let frontmost, isCandidate(frontmost) {
            result.removeAll { $0 == frontmost }
            result.insert(frontmost, at: 0)
        }
        return result
    }
}

/// 누를 때 정한 앱 순서대로 최소화할 창을 내준다.
public struct MinimizeQueue<Window> {
    private let query: (Int32) -> [Window]?
    private let front: Int32?
    private var pids: [Int32]
    private var windows: [Window] = []

    /// 앱 순서와 앱의 창 목록 조회(응답 지연이면 nil)로 만든다.
    public init(pids: [Int32], query: @escaping (Int32) -> [Window]?) {
        self.pids = pids
        self.query = query
        front = pids.first
    }

    /// 맨 앞 창. 맨 앞 앱 창 목록이 응답 지연이면 nil, 뒤쪽 앱이 응답 지연이면 그 앱을 건너뛴다.
    public mutating func peek() -> Window? {
        while windows.isEmpty, let pid = pids.first {
            let found = query(pid)
            if found == nil, pid == front { return nil }
            pids.removeFirst()
            windows = found ?? []
        }
        return windows.first
    }

    /// 맨 앞 창을 뺀다.
    public mutating func drop() {
        guard !windows.isEmpty else { return }
        windows.removeFirst()
    }

    /// 지금 앱의 남은 창과 창이 있는 다음 앱 하나의 창. 응답 지연인 앱은 건너뛴다.
    public func upcoming() -> [Window] {
        windows + (pids.lazy.compactMap { query($0) }.first { !$0.isEmpty } ?? [])
    }
}
