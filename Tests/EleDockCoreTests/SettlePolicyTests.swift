import Testing

@testable import EleDockCore

struct SettleScheduleTests {
    @Test func deadlineGrowsWithPendingCount() {
        let schedule = SettleSchedule(start: 10, pendingCount: 4)
        #expect(schedule.earliest == 10 + SettleSchedule.earliestDelay)
        #expect(schedule.deadline == 10 + SettleSchedule.baseWait + 4 * SettleSchedule.perItemWait)
        #expect(schedule.limit == schedule.deadline + SettleSchedule.maximumExtension)
    }

    @Test func resendAllowedOnlyWithinLimitAfterRelease() {
        let schedule = SettleSchedule(start: 10, pendingCount: 6)
        #expect(schedule.allowsResend(at: 10 + SettleSchedule.resendLimit - 0.01))
        #expect(!schedule.allowsResend(at: 10 + SettleSchedule.resendLimit))
        #expect(!schedule.allowsResend(at: schedule.deadline))
    }

    @Test func resendLimitFitsInsideEverySchedule() {
        #expect(SettleSchedule.resendLimit <= SettleSchedule(start: 0, pendingCount: 0).limit)
        #expect(SettleSchedule.resendLimit > SettleSchedule(start: 0, pendingCount: 1).deadline)
    }

    @Test func resendCheckFallsBetweenEarliestDelayAndResendLimit() {
        #expect(SettleSchedule.resendCheckDelay > SettleSchedule.earliestDelay)
        #expect(SettleSchedule.resendCheckDelay + SettleSchedule.checkInterval < SettleSchedule.resendLimit)
    }

    @Test(arguments: [4, 5, 8])
    func minimizeIsJudgedWithinResendLimit(pendingCount: Int) {
        let start = 10.0
        let schedule = SettleSchedule(start: start, pendingCount: pendingCount)
        #expect(schedule.deadline >= start + SettleSchedule.resendLimit)
        let checks = (1...).lazy.map { start + Double($0) * SettleSchedule.checkInterval }
        let firstDue = checks.first { schedule.minimizePhase(at: $0) == .due }
        #expect(firstDue.map { schedule.allowsResend(at: $0) } == true)
        var confirmations = MinimizeConfirmations<String, String> { $0 }
        confirmations.record("a")
        let resend = confirmations.resolve(
            phase: schedule.minimizePhase(at: firstDue ?? start), minimizedState: { _ in false },
            canResend: { _ in schedule.allowsResend(at: firstDue ?? start) })
        #expect(resend == ["a"])
    }

    @Test(arguments: [0, 3])
    func minimizePhaseIsDueFromResendCheckDelay(pendingCount: Int) {
        let schedule = SettleSchedule(start: 0, pendingCount: pendingCount)
        #expect(schedule.resendCheck == SettleSchedule.resendCheckDelay)
        #expect(schedule.minimizePhase(at: schedule.resendCheck - 0.01) == .waiting)
        #expect(schedule.minimizePhase(at: schedule.resendCheck) == .due)
        #expect(schedule.minimizePhase(at: schedule.limit) == .expired)
    }

    @Test func phasesFollowTime() {
        let schedule = SettleSchedule(start: 0, pendingCount: 1)
        #expect(schedule.phase(at: 0) == .early)
        #expect(schedule.phase(at: schedule.earliest) == .waiting)
        #expect(schedule.phase(at: schedule.deadline) == .due)
        #expect(schedule.phase(at: schedule.limit) == .expired)
    }
}

struct RestoreConfirmationsTests {
    private func confirmations(_ sent: [String]) -> RestoreConfirmations<String, String> {
        var confirmations = RestoreConfirmations<String, String> { $0 }
        for entry in sent { confirmations.record(entry) }
        return confirmations
    }

    @Test func notificationConfirmsRestore() {
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
                    return true
                })
        }
        #expect(confirmations.unconfirmed == ["a"])
    }

    @Test func dueSettlesMinimizedAndConfirmsRestored() {
        var confirmations = confirmations(["c", "b", "a"])
        let states: [String: Bool] = ["a": true, "b": false, "c": true]
        confirmations.resolve(phase: .due, minimizedState: { states[$0] })
        #expect(confirmations.isResolved)
        #expect(confirmations.focusTarget == "b")
    }

    @Test func dueKeepsUnknownUntilExpired() {
        var confirmations = confirmations(["a"])
        confirmations.resolve(phase: .due, minimizedState: { _ in nil })
        #expect(confirmations.unconfirmed == ["a"])
        confirmations.resolve(phase: .expired, minimizedState: { _ in nil })
        #expect(confirmations.isResolved)
        #expect(confirmations.focusTarget == nil)
    }

    @Test func focusesLastSentConfirmedRestore() {
        var confirmations = confirmations(["a", "b", "c"])
        #expect(confirmations.focusTarget == nil)
        confirmations.confirm("b")
        confirmations.confirm("a")
        #expect(confirmations.focusTarget == "b")
        confirmations.confirm("c")
        #expect(confirmations.focusTarget == "c")
    }

    @Test func newRepeatKeepsUnconfirmedButResetsFocus() {
        var confirmations = confirmations(["a", "b"])
        confirmations.confirm("b")
        confirmations.beginRepeat()
        #expect(confirmations.unconfirmed == ["a"])
        #expect(confirmations.focusTarget == nil)
        confirmations.confirm("a")
        #expect(confirmations.focusTarget == nil)
    }

    @Test func resentEntryIsTrackedOnce() {
        let confirmations = confirmations(["a", "a"])
        #expect(confirmations.unconfirmed == ["a"])
    }

    @Test func discardedEntriesAreNotJudged() {
        var confirmations = confirmations(["a1", "b1"])
        confirmations.discard { $0.hasPrefix("a") }
        #expect(confirmations.unconfirmed == ["b1"])
        var judged: [String] = []
        confirmations.resolve(
            phase: .expired,
            minimizedState: {
                judged.append($0)
                return true
            })
        #expect(judged == ["b1"])
        #expect(confirmations.isResolved)
    }

    @Test func confirmRightAfterRecordStaysConfirmed() {
        var confirmations = confirmations(["a"])
        confirmations.confirm("a")
        #expect(confirmations.isResolved)
        confirmations.resolve(
            phase: .expired,
            minimizedState: { _ in
                Issue.record("상태 조회가 불렸다")
                return true
            })
        #expect(confirmations.focusTarget == "a")
    }

    @Test func failedRecordIsRevertedToEarlierState() {
        var confirmations = confirmations(["a"])
        let recorded = confirmations
        confirmations.record("a")
        confirmations.record("b")
        confirmations = recorded
        #expect(confirmations.unconfirmed == ["a"])
        #expect(confirmations.focusTarget == nil)
    }
}

struct MinimizeFocusTests {
    private func focus(
        pending: String?, candidates: [String], states: [String: Bool], expired: Bool = false
    ) -> String? {
        switch RepeatPolicy.minimizeFocus(
            pending: pending, candidates: candidates, app: { $0.first }, key: { $0 }, expired: expired,
            minimizedState: { states[$0] })
        {
        case .focus(let entry): entry
        case .wait: "wait"
        case .none: nil
        }
    }

    @Test func focusesPendingWindowWhenNotMinimized() {
        #expect(focus(pending: "a1", candidates: ["a1", "b1"], states: ["a1": false, "b1": false]) == "a1")
    }

    @Test func unknownPendingWaitsInsteadOfOtherApp() {
        #expect(focus(pending: "a1", candidates: ["a1", "b1"], states: ["b1": false]) == "wait")
    }

    @Test func minimizedPendingFallsToSameAppWindow() {
        let states: [String: Bool] = ["a1": true, "b1": false, "a2": false]
        #expect(focus(pending: "a1", candidates: ["a1", "b1", "a2"], states: states) == "a2")
    }

    @Test func unknownSameAppWindowWaits() {
        let states: [String: Bool] = ["a1": true, "b1": false]
        #expect(focus(pending: "a1", candidates: ["a1", "a2", "b1"], states: states) == "wait")
    }

    @Test func otherAppOnlyWhenSameAppIsAllMinimized() {
        let states: [String: Bool] = ["a1": true, "a2": true, "b1": true, "c1": false]
        #expect(focus(pending: "a1", candidates: ["a1", "a2", "b1", "c1"], states: states) == "c1")
    }

    @Test func expiredUnknownSameAppSkipsFocus() {
        let states: [String: Bool] = ["b1": false]
        #expect(focus(pending: "a1", candidates: ["a1", "b1"], states: states, expired: true) == nil)
    }

    @Test func expiredStillFocusesConfirmedSameAppWindow() {
        let states: [String: Bool] = ["a2": false, "b1": false]
        #expect(focus(pending: "a1", candidates: ["a1", "a2", "b1"], states: states, expired: true) == "a2")
    }

    @Test func noPendingSkipsFocusWithoutQuerying() {
        let target = RepeatPolicy.minimizeFocus(
            pending: String?.none, candidates: ["b"], app: { $0 }, key: { $0 }, expired: false,
            minimizedState: { _ in
                Issue.record("상태 조회가 불렸다")
                return false
            })
        guard case .none = target else {
            Issue.record("expected none")
            return
        }
    }
}
