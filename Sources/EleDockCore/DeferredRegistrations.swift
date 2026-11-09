/// 알림 등록 한 번의 결과.
public enum RegistrationOutcome: Equatable, Sendable {
    /// 등록됐거나 이미 등록돼 있다.
    case registered
    /// 응답 지연으로 등록하지 못했다.
    case busy
    /// 대상이 이미 사라졌다.
    case gone
    /// 그 외 실패.
    case failed
}

/// 등록을 미룬 알림 대상.
public struct DeferredRegistrations<Element: Equatable, Group: Equatable> {
    /// 대상 하나에 허용하는 등록 시도 flush 수.
    public static var attemptLimit: Int { 8 }

    private let group: (Element) -> Group
    private var entries: [(element: Element, attempts: Int)] = []

    /// 대상을 앱 단위로 묶는 키로 만든다.
    public init(group: @escaping (Element) -> Group) {
        self.group = group
    }

    /// 등록을 기다리는 대상(미룬 순서).
    public var pending: [Element] { entries.map(\.element) }

    /// 등록을 기다리는 대상이 없다.
    public var isEmpty: Bool { entries.isEmpty }

    /// 등록을 미룬다.
    public mutating func add(_ element: Element) {
        guard !entries.contains(where: { $0.element == element }) else { return }
        entries.append((element, 0))
    }

    /// `element` 를 목록에서 뺀다.
    public mutating func remove(_ element: Element) {
        entries.removeAll { $0.element == element }
    }

    /// 조건에 맞는 대상을 목록에서 뺀다.
    public mutating func removeAll(where shouldRemove: (Element) -> Bool) {
        entries.removeAll { shouldRemove($0.element) }
    }

    /// 미룬 대상을 등록해 보고 사라진 대상을 돌려준다.
    public mutating func flush(register: (Element) -> RegistrationOutcome) -> [Element] {
        var gone: [Element] = []
        var busyGroups: [Group] = []
        var kept: [(element: Element, attempts: Int)] = []
        for entry in entries {
            let key = group(entry.element)
            if !busyGroups.contains(key) {
                switch register(entry.element) {
                case .busy:
                    busyGroups.append(key)
                case .gone:
                    gone.append(entry.element)
                    continue
                case .registered, .failed:
                    continue
                }
            }
            let attempts = entry.attempts + 1
            if attempts < Self.attemptLimit { kept.append((entry.element, attempts)) }
        }
        entries = kept
        return gone
    }
}
