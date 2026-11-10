import Foundation
import Testing

@testable import EleDockCore

struct RepeatPolicyTests {
    private func advance(_ queue: inout [String], results: [String: RepeatPolicy.Attempt]) -> (String?, [String]) {
        var tried: [String] = []
        let entry = RepeatPolicy.advance(
            peek: { queue.first }, drop: { queue.removeFirst() },
            attempt: {
                tried.append($0)
                return results[$0, default: .failure]
            })
        return (entry, tried)
    }

    @Test func busyCountsAsSent() {
        var queue = ["a", "b"]
        let (entry, tried) = advance(&queue, results: ["a": .busy, "b": .success])
        #expect(entry == "a")
        #expect(tried == ["a"])
        #expect(queue == ["b"])
    }

    @Test func sameAppBusyTicksAdvanceOneCandidateEach() {
        var queue = ["a", "b", "c"]
        var sent: [String] = []
        for _ in 0..<3 {
            let (entry, _) = advance(&queue, results: ["a": .busy, "b": .busy, "c": .busy])
            if let entry { sent.append(entry) }
        }
        #expect(sent == ["a", "b", "c"])
        #expect(queue.isEmpty)
    }

    @Test func failureDropsAndTriesNextInSameTick() {
        var queue = ["a", "b", "c"]
        let (entry, tried) = advance(&queue, results: ["a": .failure, "b": .success])
        #expect(entry == "b")
        #expect(tried == ["a", "b"])
        #expect(queue == ["c"])
    }

    @Test func failureThenBusySendsBusyCandidate() {
        var queue = ["a", "b", "c"]
        let (entry, _) = advance(&queue, results: ["a": .failure, "b": .busy])
        #expect(entry == "b")
        #expect(queue == ["c"])
    }

    @Test func allFailuresDrainQueue() {
        var queue = ["a", "b"]
        let (entry, _) = advance(&queue, results: [:])
        #expect(entry == nil)
        #expect(queue.isEmpty)
    }

    @Test func emptyQueueDoesNothing() {
        var queue: [String] = []
        let (entry, tried) = advance(&queue, results: [:])
        #expect(entry == nil)
        #expect(tried.isEmpty)
    }

    @Test func fastTickKeepsIntervalFromStart() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let fire = RepeatPolicy.nextFire(tickStart: start, tickEnd: start.addingTimeInterval(0.1))
        #expect(fire == start.addingTimeInterval(RepeatPolicy.interval))
    }

    @Test func tickOfExactIntervalWaitsIntervalAfterEnd() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let end = start.addingTimeInterval(RepeatPolicy.interval)
        #expect(RepeatPolicy.nextFire(tickStart: start, tickEnd: end) == end.addingTimeInterval(RepeatPolicy.interval))
    }

    @Test func slowTickWaitsIntervalAfterEnd() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let end = start.addingTimeInterval(0.57)
        #expect(RepeatPolicy.nextFire(tickStart: start, tickEnd: end) == end.addingTimeInterval(RepeatPolicy.interval))
    }
}

struct RepeatModeTests {
    @Test func unregisterStopsHotKeyRepeatButNotRestoreAll() {
        #expect(!RepeatMode.restoreAll.stopsOnUnregister)
        for kind in Shortcut.Kind.allCases {
            #expect(RepeatMode.hotKey(kind).stopsOnUnregister)
        }
    }

    @Test func restoreAllRestoresAndHotKeyFollowsItsKind() {
        #expect(RepeatMode.restoreAll.action == .restore)
        for kind in Shortcut.Kind.allCases {
            #expect(RepeatMode.hotKey(kind).action == kind)
        }
    }
}

struct RestoreAllBudgetTests {
    @Test func budgetGrowsWithWindowCount() {
        func timerTicks(windows: Int) -> Int {
            var budget = RestoreAllBudget(minimizedCount: windows)
            var ticks = 0
            while budget.consumeTick(minimizedCount: windows) { ticks += 1 }
            return ticks
        }
        #expect(timerTicks(windows: 1) + 1 == RestoreAllBudget.ticksPerWindow)
        #expect(timerTicks(windows: 3) + 1 == RestoreAllBudget.ticksPerWindow * 3)
    }

    @Test func windowBudgetOutlastsStall() {
        #expect(Double(RestoreAllBudget.ticksPerWindow) * RepeatPolicy.interval > RepeatPolicy.stallDuration)
    }

    @Test func stopsWhenNoWindowsRemain() {
        var budget = RestoreAllBudget(minimizedCount: 3)
        let first = budget.consumeTick(minimizedCount: 1)
        let second = budget.consumeTick(minimizedCount: 0)
        #expect(first)
        #expect(!second)
    }

    @Test func emptyStackStopsAtFirstTimerTick() {
        var budget = RestoreAllBudget(minimizedCount: 0)
        let proceeds = budget.consumeTick(minimizedCount: 0)
        #expect(!proceeds)
    }
}
