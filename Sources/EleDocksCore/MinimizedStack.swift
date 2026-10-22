/// 최소화된 창을 최소화한 순서대로 쌓는다.
public struct MinimizedStack<Window: Equatable> {
    /// 창과 그 창을 가진 앱의 pid.
    public struct Entry {
        /// 창을 가진 앱의 pid.
        public let pid: Int32
        /// 최소화된 창.
        public let window: Window

        /// 앱 pid 와 창으로 만든다.
        public init(pid: Int32, window: Window) {
            self.pid = pid
            self.window = window
        }
    }

    private var entries: [Entry] = []

    /// 빈 스택을 만든다.
    public init() {}

    /// 쌓인 창 수.
    public var count: Int { entries.count }
    /// 가장 최근에 최소화된 창.
    public var last: Entry? { entries.last }

    /// 창이 쌓여 있는지 확인한다.
    public func contains(_ window: Window) -> Bool {
        entries.contains { $0.window == window }
    }

    /// 새로 최소화된 창을 맨 위에 올린다.
    public mutating func push(_ entry: Entry) {
        entries.removeAll { $0.window == entry.window }
        entries.append(entry)
    }

    /// 창을 `successors` 중 가장 아래 쌓인 창 바로 밑에 넣는다.
    public mutating func insert(_ entry: Entry, below successors: [Window]) {
        entries.removeAll { $0.window == entry.window }
        let index = entries.firstIndex { successors.contains($0.window) } ?? entries.endIndex
        entries.insert(entry, at: index)
    }

    /// 순서를 모르는 창을 맨 아래에 넣는다.
    public mutating func insertAtBottom(_ entry: Entry) {
        guard !contains(entry.window) else { return }
        entries.insert(entry, at: 0)
    }

    /// 꺼낸 항목을 맨 위에 되돌린다.
    public mutating func putBack(_ entry: Entry) {
        guard !contains(entry.window) else { return }
        entries.append(entry)
    }

    /// 가장 최근 항목을 꺼낸다.
    public mutating func popLast() -> Entry? {
        entries.popLast()
    }

    /// 창을 찾아 꺼낸다.
    public mutating func take(_ window: Window) -> Entry? {
        guard let index = entries.lastIndex(where: { $0.window == window }) else { return nil }
        return entries.remove(at: index)
    }

    /// 복원되거나 사라진 창을 뺀다.
    public mutating func remove(_ window: Window) {
        entries.removeAll { $0.window == window }
    }

    /// 종료된 앱의 창을 모두 뺀다.
    public mutating func removeAll(pid: Int32) {
        entries.removeAll { $0.pid == pid }
    }

    /// 최근 순으로 최대 `limit` 개.
    public func recent(limit: Int) -> [Entry] {
        entries.suffix(limit).reversed()
    }
}
