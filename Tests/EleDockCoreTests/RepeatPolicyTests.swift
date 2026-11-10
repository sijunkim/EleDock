import Foundation
import Testing

@testable import EleDockCore

struct RepeatPolicyTests {
    private func advance(
        _ queue: inout [String], results: [String: RepeatPolicy.Attempt], waiting: Set<String> = []
    ) -> (String?, [String]) {
        var tried: [String] = []
        let entry = RepeatPolicy.advance(
            peek: { queue.first }, drop: { queue.removeFirst() }, isWaiting: { waiting.contains($0) },
            attempt: {
                tried.append($0)
                return results[$0, default: .failure]
            })
        return (entry, tried)
    }

    @Test func busyKeepsCandidateAndStopsTick() {
        var queue = ["a", "b"]
        let (entry, tried) = advance(&queue, results: ["a": .busy, "b": .success])
        #expect(entry == nil)
        #expect(tried == ["a"])
        #expect(queue == ["a", "b"])
    }

    @Test func busyCandidateIsRetriedUntilSent() {
        var queue = ["a", "b"]
        var results: [String: RepeatPolicy.Attempt] = ["a": .busy, "b": .success]
        #expect(advance(&queue, results: results).0 == nil)
        results["a"] = .success
        #expect(advance(&queue, results: results).0 == "a")
        #expect(queue == ["b"])
    }

    @Test func failureDropsAndTriesNextInSameTick() {
        var queue = ["a", "b", "c"]
        let (entry, tried) = advance(&queue, results: ["a": .failure, "b": .success])
        #expect(entry == "b")
        #expect(tried == ["a", "b"])
        #expect(queue == ["c"])
    }

    @Test func waitingCandidateIsNeitherSentNorDropped() {
        var queue = ["a", "b"]
        let (entry, tried) = advance(&queue, results: ["a": .success, "b": .success], waiting: ["a"])
        #expect(entry == nil)
        #expect(tried.isEmpty)
        #expect(queue == ["a", "b"])
    }

    @Test func waitingAfterFailureStopsWithoutSkipping() {
        var queue = ["a", "b", "c"]
        let (entry, tried) = advance(&queue, results: ["c": .success], waiting: ["b"])
        #expect(entry == nil)
        #expect(tried == ["a"])
        #expect(queue == ["b", "c"])
    }

    @Test func failureThenBusyStopsAtBusyCandidate() {
        var queue = ["a", "b", "c"]
        let (entry, _) = advance(&queue, results: ["a": .failure, "b": .busy])
        #expect(entry == nil)
        #expect(queue == ["b", "c"])
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

struct PressDemandTests {
    private let limit = RepeatPolicy.stallDuration

    @Test func quickSecondPressIsSentAfterRelease() {
        var demand = PressDemand()
        demand.press()
        demand.record(.sent, at: 0)
        demand.release()
        #expect(!demand.continues(repeats: true))
        demand.press()
        demand.release()
        demand.record(.blocked, at: 0.3)
        demand.record(.blocked, at: 0.55)
        #expect(demand.continues(repeats: true))
        demand.record(.sent, at: 0.8)
        #expect(demand.pending == 0)
        #expect(!demand.continues(repeats: true))
    }

    @Test func holdRepeatsOnlyWhileHeldAndEndsAtRelease() {
        var demand = PressDemand()
        demand.press()
        demand.record(.sent, at: 0)
        #expect(demand.continues(repeats: true))
        #expect(!demand.continues(repeats: false))
        demand.record(.blocked, at: 0.25)
        demand.record(.sent, at: 0.6)
        #expect(demand.continues(repeats: true))
        demand.release()
        #expect(!demand.continues(repeats: true))
    }

    @Test func blockedPressIsAbandonedOnceAfterStallDuration() {
        var demand = PressDemand()
        demand.press()
        demand.press()
        demand.release()
        demand.record(.blocked, at: 0)
        demand.record(.blocked, at: limit - 0.01)
        #expect(demand.pending == 2)
        demand.record(.blocked, at: limit)
        #expect(demand.pending == 1)
        demand.record(.blocked, at: limit + 0.25)
        #expect(demand.pending == 1)
    }

    @Test func newPressDoesNotExtendFrontPressLimit() {
        var demand = PressDemand()
        demand.press()
        demand.release()
        demand.record(.blocked, at: 0)
        demand.press()
        demand.release()
        demand.record(.blocked, at: limit)
        #expect(demand.pending == 1)
    }

    @Test func idleDropsAllPendingPresses() {
        var demand = PressDemand()
        demand.press()
        demand.press()
        demand.release()
        demand.record(.idle, at: 0)
        #expect(demand.pending == 0)
        #expect(!demand.continues(repeats: true))
    }

    @Test func sentPressRestartsStallForNextPress() {
        var demand = PressDemand()
        demand.press()
        demand.press()
        demand.release()
        demand.record(.blocked, at: 0)
        demand.record(.sent, at: limit - 0.01)
        demand.record(.blocked, at: limit)
        #expect(demand.pending == 1)
    }
}
