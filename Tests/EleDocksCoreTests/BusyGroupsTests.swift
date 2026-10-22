import Testing

@testable import EleDocksCore

struct BusyGroupsTests {
    private enum ReadError: Error {
        case busy, failed
    }

    private func read(_ elements: [Int], busy: Set<Int>, failed: Set<Int> = [])
        -> (attempted: [Int], values: [Int?])
    {
        var groups = BusyGroups<Int>()
        var attempted: [Int] = []
        let values = elements.map { element in
            groups.read(element / 10, isBusy: { $0 == .busy }) { () throws(ReadError) -> Int in
                attempted.append(element)
                if busy.contains(element) { throw .busy }
                if failed.contains(element) { throw .failed }
                return element
            }
        }
        return (attempted, values)
    }

    @Test func busySkipsRestOfThatGroupOnly() {
        let result = read([1, 2, 13, 3, 14], busy: [2])
        #expect(result.attempted == [1, 2, 13, 14])
        #expect(result.values == [1, nil, 13, nil, 14])
    }

    @Test func readsEveryGroupWithoutDelay() {
        let result = read([1, 12, 3], busy: [])
        #expect(result.attempted == [1, 12, 3])
        #expect(result.values == [1, 12, 3])
    }

    @Test func failureOtherThanDelayKeepsReadingThatGroup() {
        let result = read([1, 2, 3], busy: [], failed: [1])
        #expect(result.attempted == [1, 2, 3])
        #expect(result.values == [nil, 2, 3])
    }
}
