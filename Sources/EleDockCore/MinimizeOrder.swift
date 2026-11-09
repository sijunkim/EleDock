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

    /// 앱별 창 목록을 앞→뒤로 모은다.
    public static func windows<Window>(pids: [Int32], frontmost: Int32?, query: (Int32) -> [Window]?) -> [Window]? {
        var result: [Window] = []
        for pid in pids {
            guard let windows = query(pid) else {
                if pid == frontmost { return nil }
                continue
            }
            result += windows
        }
        return result
    }
}
