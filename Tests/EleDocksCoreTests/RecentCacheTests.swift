import Testing

@testable import EleDocksCore

struct RecentCacheTests {
    @Test func keepsValuesUpToCapacityDroppingOldest() {
        var cache = RecentCache<Int, String>(capacity: 3)
        for key in 1...4 { cache.insert("v\(key)", for: key) }
        #expect(cache.count == 3)
        #expect(cache.value(for: 1) == nil)
        #expect(cache.value(for: 2) == "v2")
        #expect(cache.value(for: 4) == "v4")
    }

    @Test func reinsertReplacesValueAndMakesItNewest() {
        var cache = RecentCache<Int, String>(capacity: 2)
        cache.insert("a", for: 1)
        cache.insert("b", for: 2)
        cache.insert("a2", for: 1)
        cache.insert("c", for: 3)
        #expect(cache.count == 2)
        #expect(cache.value(for: 1) == "a2")
        #expect(cache.value(for: 2) == nil)
        #expect(cache.value(for: 3) == "c")
    }

    @Test func removesByKeyAndByCondition() {
        var cache = RecentCache<Int, (owner: Int, name: String)>(capacity: 5)
        cache.insert((10, "a"), for: 1)
        cache.insert((20, "b"), for: 2)
        cache.insert((10, "c"), for: 3)
        cache.remove(2)
        #expect(cache.value(for: 2) == nil)
        cache.removeAll { $1.owner == 10 }
        #expect(cache.count == 0)
        cache.remove(9)
        #expect(cache.count == 0)
    }
}
