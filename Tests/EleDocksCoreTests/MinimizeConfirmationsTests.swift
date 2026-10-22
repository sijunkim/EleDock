import Testing

@testable import EleDocksCore

struct MinimizeConfirmationsTests {
    private func confirmations(_ sent: [String]) -> MinimizeConfirmations<String, String> {
        var confirmations = MinimizeConfirmations<String, String> { $0 }
        for entry in sent { confirmations.record(entry) }
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
            let resend = confirmations.resolve(
                phase: phase,
                minimizedState: { _ in
                    Issue.record("상태 조회가 불렸다")
                    return false
                }, canResend: { _ in true })
            #expect(resend.isEmpty)
        }
        #expect(confirmations.unconfirmed == ["a"])
    }

    @Test func dueResendsOnlyUnminimizedInSentOrder() {
        var confirmations = confirmations(["a", "b", "c"])
        let states: [String: Bool] = ["a": false, "b": true, "c": false]
        #expect(
            confirmations.resolve(phase: .due, minimizedState: { states[$0] }, canResend: { _ in true }) == ["a", "c"])
        #expect(confirmations.isResolved)
    }

    @Test func resendsOnlyOnce() {
        var confirmations = confirmations(["a"])
        #expect(confirmations.resolve(phase: .due, minimizedState: { _ in false }, canResend: { _ in true }) == ["a"])
        #expect(confirmations.resolve(phase: .due, minimizedState: { _ in false }, canResend: { _ in true }).isEmpty)
    }

    @Test func unknownWaitsUntilExpiredThenDropsWithoutResend() {
        var confirmations = confirmations(["a"])
        #expect(confirmations.resolve(phase: .due, minimizedState: { _ in nil }, canResend: { _ in true }).isEmpty)
        #expect(confirmations.unconfirmed == ["a"])
        #expect(confirmations.resolve(phase: .expired, minimizedState: { _ in nil }, canResend: { _ in true }).isEmpty)
        #expect(confirmations.isResolved)
    }

    @Test func confirmedEntryIsNotResent() {
        var confirmations = confirmations(["a"])
        confirmations.confirm("a")
        let resend = confirmations.resolve(
            phase: .due,
            minimizedState: { _ in
                Issue.record("상태 조회가 불렸다")
                return false
            }, canResend: { _ in true })
        #expect(resend.isEmpty)
    }

    @Test func resentEntryIsTrackedOnce() {
        let confirmations = confirmations(["a", "b", "a"])
        #expect(confirmations.unconfirmed == ["b", "a"])
    }

    @Test func resentConfirmationReturnsLaterSentWindows() {
        var confirmations = confirmations(["a", "b", "c"])
        #expect(confirmations.confirm("b") == nil)
        #expect(
            confirmations.resolve(phase: .due, minimizedState: { _ in false }, canResend: { _ in true }) == ["a", "c"])
        #expect(confirmations.confirm("a") == ["b", "c"])
        #expect(confirmations.confirm("c") == [])
        #expect(confirmations.confirm("a") == nil)
    }

    @Test func beginRepeatKeepsUnconfirmedAndDropsResentPlacement() {
        var confirmations = confirmations(["a", "b"])
        #expect(
            confirmations.resolve(phase: .due, minimizedState: { $0 == "a" ? false : nil }, canResend: { _ in true })
                == ["a"])
        confirmations.beginRepeat()
        #expect(confirmations.unconfirmed == ["b"])
        #expect(confirmations.confirm("a") == nil)
    }

    @Test func sendingAgainDropsResentPlacement() {
        var confirmations = confirmations(["a", "b"])
        _ = confirmations.resolve(phase: .due, minimizedState: { _ in false }, canResend: { _ in true })
        confirmations.record("a")
        #expect(confirmations.confirm("a") == nil)
    }

    @Test func discardedEntriesAreNotResent() {
        var confirmations = confirmations(["a1", "b1"])
        confirmations.discard { $0.hasPrefix("a") }
        #expect(
            confirmations.resolve(phase: .expired, minimizedState: { _ in false }, canResend: { _ in true }) == ["b1"])
    }

    @Test func refusedResendIsDroppedWithoutResending() {
        var confirmations = confirmations(["a", "b"])
        let resend = confirmations.resolve(
            phase: .due, minimizedState: { _ in false }, canResend: { $0 == "b" })
        #expect(resend == ["b"])
        #expect(confirmations.isResolved)
        #expect(confirmations.confirm("a") == nil)
    }

    @Test func resendIsAskedOnlyForUnminimizedEntries() {
        var confirmations = confirmations(["a", "b"])
        let states: [String: Bool] = ["a": true]
        let resend = confirmations.resolve(
            phase: .due, minimizedState: { states[$0] },
            canResend: { entry in
                Issue.record("재전송 판정이 불렸다: \(entry)")
                return true
            })
        #expect(resend.isEmpty)
        #expect(confirmations.unconfirmed == ["b"])
    }
}
