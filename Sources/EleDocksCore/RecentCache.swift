/// 최근에 넣은 값을 `capacity` 개까지 두는 캐시.
public struct RecentCache<Key: Equatable, Value> {
    /// 보관하는 값 수.
    public let capacity: Int

    private var entries: [(key: Key, value: Value)] = []

    /// 빈 캐시를 만든다.
    public init(capacity: Int) {
        self.capacity = capacity
    }

    /// 보관 중인 값 수.
    public var count: Int { entries.count }

    /// `key` 의 값.
    public func value(for key: Key) -> Value? {
        entries.first { $0.key == key }?.value
    }

    /// 가장 최근 값으로 넣는다.
    public mutating func insert(_ value: Value, for key: Key) {
        remove(key)
        entries.append((key, value))
        if entries.count > capacity {
            entries.removeFirst(entries.count - capacity)
        }
    }

    /// `key` 의 값을 버린다.
    public mutating func remove(_ key: Key) {
        entries.removeAll { $0.key == key }
    }

    /// 조건에 맞는 값을 모두 버린다.
    public mutating func removeAll(where shouldRemove: (Key, Value) -> Bool) {
        entries.removeAll { shouldRemove($0.key, $0.value) }
    }
}
