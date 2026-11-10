import Foundation
import Testing

@testable import EleDockCore

struct RestoreNextTests {
    /// `restoreNext` 테스트 하네스.
    private struct Harness {
        var stack: [String]
        var stall = Stall<String>()
        var tried: [String] = []
        var queried: [String] = []
        var now: TimeInterval = 0

        init(_ stack: [String]) {
            self.stack = stack
        }

        mutating func run(
            minimized: [String: Bool], results: [String: RepeatPolicy.Attempt], waiting: Set<String> = []
        ) -> String? {
            var stack = self.stack
            var tried: [String] = []
            var queried: [String] = []
            let restored = RepeatPolicy.restoreNext(
                pop: { stack.popLast() }, putBack: { stack.append($0) }, moveToBottom: { stack.insert($0, at: 0) },
                key: { $0 }, stall: &stall, now: now, isWaiting: { waiting.contains($0) },
                minimizedState: {
                    queried.append($0)
                    return minimized[$0]
                },
                restore: {
                    tried.append($0)
                    return results[$0, default: .failure]
                })
            (self.stack, self.tried, self.queried) = (stack, tried, queried)
            return restored
        }
    }

    @Test func restoresTopMinimizedWindow() {
        var harness = Harness(["a", "b"])
        let restored = harness.run(minimized: ["a": true, "b": true], results: ["b": .success])
        #expect(restored == "b")
        #expect(harness.tried == ["b"])
        #expect(harness.stack == ["a"])
    }

    @Test func busyRestoreKeepsWindowOnTopAndStops() {
        var harness = Harness(["a", "b"])
        let restored = harness.run(minimized: ["a": true, "b": true], results: ["a": .success, "b": .busy])
        #expect(restored == nil)
        #expect(harness.tried == ["b"])
        #expect(harness.stack == ["a", "b"])
    }

    @Test func waitingTopIsPutBackWithoutQueryOrStall() {
        var harness = Harness(["a", "b"])
        for now in [0, RepeatPolicy.stallDuration, 2 * RepeatPolicy.stallDuration] {
            harness.now = now
            #expect(harness.run(minimized: ["a": true, "b": true], results: ["b": .success], waiting: ["b"]) == nil)
            #expect(harness.queried.isEmpty)
            #expect(harness.tried.isEmpty)
            #expect(harness.stack == ["a", "b"])
        }
        #expect(harness.run(minimized: ["a": true, "b": true], results: ["b": .success]) == "b")
    }

    @Test func failedRestoreDropsWindowAndTriesNext() {
        var harness = Harness(["a", "b"])
        let restored = harness.run(minimized: ["a": true, "b": true], results: ["a": .success, "b": .failure])
        #expect(restored == "a")
        #expect(harness.tried == ["b", "a"])
        #expect(harness.stack.isEmpty)
    }

    @Test func notMinimizedWindowIsDroppedWithoutRestoring() {
        var harness = Harness(["a", "b"])
        let restored = harness.run(minimized: ["a": true, "b": false], results: ["a": .success])
        #expect(restored == "a")
        #expect(harness.tried == ["a"])
        #expect(harness.queried == ["b", "a"])
    }

    @Test func unknownStateKeepsWindowOnTopAndStops() {
        var harness = Harness(["a", "b"])
        let restored = harness.run(minimized: ["a": true], results: ["a": .success])
        #expect(restored == nil)
        #expect(harness.tried.isEmpty)
        #expect(harness.stack == ["a", "b"])
    }

    @Test func drainedStackIsEmpty() {
        var harness = Harness(["a", "b"])
        let restored = harness.run(minimized: ["a": false, "b": true], results: [:])
        #expect(restored == nil)
        #expect(harness.stack.isEmpty)
        var empty = Harness([])
        #expect(empty.run(minimized: [:], results: [:]) == nil)
    }

    @Test func repeatedUnknownStateMovesTopToBottom() {
        var harness = Harness(["a", "b", "c"])
        let minimized = ["a": true, "b": true]
        let restored1 = harness.run(minimized: minimized, results: ["b": .success])
        #expect(restored1 == nil)
        #expect(harness.stack == ["a", "b", "c"])
        harness.now = RepeatPolicy.stallDuration
        let restored2 = harness.run(minimized: minimized, results: ["b": .success])
        #expect(restored2 == "b")
        #expect(harness.stack == ["c", "a"])
    }

    @Test func repeatedBusyRestoreMovesTopToBottom() {
        var harness = Harness(["a", "b", "c"])
        let minimized = ["a": true, "b": true, "c": true]
        let results: [String: RepeatPolicy.Attempt] = ["b": .success, "c": .busy]
        let restored1 = harness.run(minimized: minimized, results: results)
        #expect(restored1 == nil)
        harness.now = RepeatPolicy.stallDuration
        let restored2 = harness.run(minimized: minimized, results: results)
        #expect(restored2 == "b")
        #expect(harness.tried == ["c", "b"])
        #expect(harness.stack == ["c", "a"])
    }

    @Test func busyRestoreBeforeStallDurationKeepsOrder() {
        var harness = Harness(["a", "b"])
        let minimized = ["a": true, "b": true]
        let results: [String: RepeatPolicy.Attempt] = ["a": .success, "b": .busy]
        for now in [0, 0.5, RepeatPolicy.stallDuration - 0.01] {
            harness.now = now
            #expect(harness.run(minimized: minimized, results: results) == nil)
            #expect(harness.stack == ["a", "b"])
        }
        harness.now = RepeatPolicy.stallDuration
        #expect(harness.run(minimized: minimized, results: results) == "a")
        #expect(harness.stack == ["b"])
    }

    @Test func stallCountIsPerConsecutiveEntry() {
        var harness = Harness(["a", "b"])
        #expect(harness.run(minimized: ["a": true], results: [:]) == nil)
        harness.stack = ["b", "a"]
        #expect(harness.run(minimized: ["b": true], results: [:]) == nil)
        #expect(harness.stack == ["b", "a"])
        harness.stack = ["a", "b"]
        #expect(harness.run(minimized: ["a": true, "b": true], results: ["b": .success]) == "b")
        #expect(harness.run(minimized: [:], results: [:]) == nil)
        #expect(harness.stack == ["a"])
    }

    @Test func lonelyStalledEntryIsNotRetriedInSameTick() {
        var harness = Harness(["a"])
        #expect(harness.run(minimized: [:], results: [:]) == nil)
        harness.now = RepeatPolicy.stallDuration
        #expect(harness.run(minimized: [:], results: [:]) == nil)
        #expect(harness.queried == ["a"])
        #expect(harness.stack == ["a"])
    }
}
