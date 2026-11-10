import Testing

@testable import EleDockCore

struct MinimizeConfirmationsTests {
    private func confirmations(_ sent: [String]) -> Confirmations<String, String, Character?> {
        var confirmations = Confirmations<String, String, Character?>(key: { $0 }, app: \.first, minimized: true)
        for entry in sent { confirmations.record(entry, at: 0) }
        return confirmations
    }

    @Test func notificationConfirmsMinimize() {
        var confirmations = confirmations(["a", "b"])
        confirmations.confirm("a")
        #expect(confirmations.unconfirmed == ["b"])
        confirmations.confirm("b")
        #expect(confirmations.isResolved)
    }

    @Test func waitsForNotificationsBeforeDeadline() {
        var confirmations = confirmations(["a"])
        for phase in [SettleSchedule.Phase.early, .waiting] {
            confirmations.resolve(
                phase: phase,
                minimizedState: { _ in
                    Issue.record("상태 조회가 불렸다")
                    return false
                }, abandon: { _ in })
        }
        #expect(confirmations.unconfirmed == ["a"])
    }

    @Test func dueSettlesBothMinimizedAndNotMinimized() {
        var confirmations = confirmations(["a", "b", "c"])
        let states: [String: Bool] = ["a": false, "b": true]
        var abandoned: [String] = []
        confirmations.resolve(phase: .due, minimizedState: { states[$0] }, abandon: { abandoned.append($0) })
        #expect(confirmations.unconfirmed == ["c"])
        #expect(abandoned == ["a"])
        confirmations.resolve(phase: .expired, minimizedState: { states[$0] }, abandon: { abandoned.append($0) })
        #expect(confirmations.isResolved)
        #expect(abandoned == ["a", "c"])
    }

    @Test func resentEntryIsTrackedOnce() {
        let confirmations = confirmations(["a", "b", "a"])
        #expect(confirmations.unconfirmed == ["a", "b"])
    }

    @Test func discardedEntriesAreNotJudged() {
        var confirmations = confirmations(["a1", "b1"])
        confirmations.discard { $0.hasPrefix("a") }
        #expect(confirmations.unconfirmed == ["b1"])
    }

    @Test func failedRecordIsRevertedToEarlierState() {
        var confirmations = confirmations(["a"])
        let recorded = confirmations
        confirmations.record("b", at: 0)
        confirmations = recorded
        #expect(confirmations.unconfirmed == ["a"])
    }
}

struct ConfirmationAwaitTests {
    private func minimizes(_ sent: [String]) -> Confirmations<String, String, Character?> {
        var confirmations = Confirmations<String, String, Character?>(key: { $0 }, app: \.first, minimized: true)
        for entry in sent { confirmations.record(entry, at: 0) }
        return confirmations
    }

    private func awaits(
        _ confirmations: inout Confirmations<String, String, Character?>, _ owner: Character, at now: Double,
        states: [String: Bool], abandoned: inout [String]
    ) -> Bool {
        confirmations.awaits(owner, at: now, minimizedState: { states[$0] }, abandon: { abandoned.append($0) })
    }

    @Test func reflectedRequestIsConfirmedAndDoesNotWait() {
        var confirmations = minimizes(["a1"])
        var abandoned: [String] = []
        #expect(!awaits(&confirmations, "a", at: 0, states: ["a1": true], abandoned: &abandoned))
        #expect(confirmations.isResolved)
        #expect(abandoned.isEmpty)
    }

    @Test(arguments: [false, nil] as [Bool?])
    func unreflectedOrBusyRequestWaits(state: Bool?) {
        var confirmations = minimizes(["a1"])
        var abandoned: [String] = []
        let states = state.map { ["a1": $0] } ?? [:]
        #expect(awaits(&confirmations, "a", at: 0, states: states, abandoned: &abandoned))
        #expect(confirmations.unconfirmed == ["a1"])
    }

    @Test func otherAppRequestDoesNotWait() {
        var confirmations = minimizes(["b1"])
        var abandoned: [String] = []
        #expect(!awaits(&confirmations, "a", at: 0, states: [:], abandoned: &abandoned))
        #expect(confirmations.unconfirmed == ["b1"])
    }

    @Test func requestPastStallLimitIsAbandoned() {
        var confirmations = minimizes(["a1", "a2"])
        var abandoned: [String] = []
        let states = ["a1": false, "a2": true]
        let limit = RepeatPolicy.stallDuration
        #expect(awaits(&confirmations, "a", at: 0, states: states, abandoned: &abandoned))
        #expect(awaits(&confirmations, "a", at: limit - 0.01, states: states, abandoned: &abandoned))
        #expect(abandoned.isEmpty)
        #expect(!awaits(&confirmations, "a", at: limit, states: states, abandoned: &abandoned))
        #expect(abandoned == ["a1"])
        #expect(confirmations.isResolved)
    }

    @Test func waitLimitCountsFromSendTime() {
        var confirmations = minimizes([])
        confirmations.record("a1", at: 10)
        var abandoned: [String] = []
        let limit = RepeatPolicy.stallDuration
        #expect(awaits(&confirmations, "a", at: 10 + limit - 0.01, states: [:], abandoned: &abandoned))
        #expect(abandoned.isEmpty)
        #expect(!awaits(&confirmations, "a", at: 10 + limit, states: [:], abandoned: &abandoned))
        #expect(abandoned == ["a1"])
    }

    @Test func sameWindowSentAgainWaitsFromStart() {
        var confirmations = minimizes(["a1"])
        var abandoned: [String] = []
        let limit = RepeatPolicy.stallDuration
        #expect(awaits(&confirmations, "a", at: 0, states: ["a1": false], abandoned: &abandoned))
        #expect(awaits(&confirmations, "a", at: 1, states: ["a1": false], abandoned: &abandoned))
        #expect(!awaits(&confirmations, "a", at: 1.25, states: ["a1": true], abandoned: &abandoned))
        confirmations.record("a1", at: 10)
        #expect(awaits(&confirmations, "a", at: 10, states: ["a1": false], abandoned: &abandoned))
        #expect(awaits(&confirmations, "a", at: 10 + limit - 0.01, states: ["a1": false], abandoned: &abandoned))
        #expect(abandoned.isEmpty)
    }

    @Test func resendingPendingRequestRestartsWait() {
        var confirmations = minimizes(["a1"])
        var abandoned: [String] = []
        let limit = RepeatPolicy.stallDuration
        confirmations.record("a1", at: 1)
        #expect(awaits(&confirmations, "a", at: limit, states: [:], abandoned: &abandoned))
        #expect(confirmations.unconfirmed == ["a1"])
        #expect(abandoned.isEmpty)
    }

    @Test func restoreWaitsUntilWindowIsNotMinimized() {
        var confirmations = Confirmations<String, String, Character?>(key: { $0 }, app: \.first, minimized: false)
        confirmations.record("a1", at: 0)
        var abandoned: [String] = []
        #expect(awaits(&confirmations, "a", at: 0, states: ["a1": true], abandoned: &abandoned))
        #expect(!awaits(&confirmations, "a", at: 0.25, states: ["a1": false], abandoned: &abandoned))
        #expect(confirmations.focusTarget == "a1")
    }

    @Test func sameAppRestoreWaitsWithoutTouchingStack() {
        var restores = Confirmations<String, String, Character?>(key: { $0 }, app: \.first, minimized: false)
        restores.record("a1", at: 0)
        var stack = ["b1", "a2"]
        var stall = Stall<String>()
        var queried: [String] = []
        let restore = { () -> String? in
            RepeatPolicy.restoreNext(
                pop: { stack.popLast() }, putBack: { if !stack.contains($0) { stack.append($0) } },
                moveToBottom: { stack.insert($0, at: 0) }, key: { $0 }, stall: &stall, now: 0,
                isWaiting: { entry in
                    restores.awaits(entry.first, at: 0, minimizedState: { _ in true }, abandon: { _ in })
                },
                minimizedState: {
                    queried.append($0)
                    return true
                }, restore: { _ in .success })
        }
        #expect(restore() == nil)
        #expect(queried.isEmpty)
        #expect(stack == ["b1", "a2"])
        stack = ["a2", "b1"]
        #expect(restore() == "b1")
        #expect(stack == ["a2"])
    }

    @Test func unreflectedRestoresReturnToTopInSentOrderAtSettle() {
        var restores = Confirmations<String, String, Character?>(key: { $0 }, app: \.first, minimized: false)
        var stack = ["x"]
        for entry in ["c", "b", "a"] { restores.record(entry, at: 0) }
        restores.resolve(
            phase: .due, minimizedState: { $0 == "b" ? false : true },
            abandon: { if !stack.contains($0) { stack.append($0) } })
        #expect(stack == ["x", "a", "c"])
        #expect(restores.isResolved)
        #expect(restores.focusTarget == "b")
    }
}
