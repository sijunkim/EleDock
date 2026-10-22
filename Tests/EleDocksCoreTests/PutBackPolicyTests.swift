import Testing

@testable import EleDocksCore

struct PutBackPolicyTests {
    @Test func restoredIsDone() {
        #expect(PutBackPolicy.decide(.restored, mismatches: 0) == .done)
        #expect(PutBackPolicy.decide(.restored, mismatches: 1) == .done)
    }

    @Test func explicitRefusalLocksImmediately() {
        #expect(PutBackPolicy.decide(.unsupported, mismatches: 0) == .lock)
    }

    @Test func locksOnlyAfterConsecutiveMismatches() {
        #expect(PutBackPolicy.decide(.mismatched, mismatches: 0) == .retry(mismatches: 1))
        #expect(PutBackPolicy.decide(.mismatched, mismatches: PutBackPolicy.mismatchLimit - 1) == .lock)
    }

    @Test func transientFailuresRetryWithoutLockAndBreakTheStreak() {
        #expect(PutBackPolicy.decide(.unresponsive, mismatches: 1) == .retry(mismatches: 0))
        #expect(PutBackPolicy.decide(.failed, mismatches: 1) == .retry(mismatches: 0))
        #expect(PutBackPolicy.decide(.failed, mismatches: 0) == .retry(mismatches: 0))
    }
}

struct AttemptSlotsTests {
    private let interval = AnimationTiming.putBackRetryInterval

    @Test func firstAttemptGetsSlotAtOnce() {
        var slots = AttemptSlots(interval: interval)
        let granted = slots.take(at: 100)
        #expect(granted)
    }

    @Test func secondAttemptWaitsForNextSlot() {
        var slots = AttemptSlots(interval: interval)
        let first = slots.take(at: 100)
        let early = slots.take(at: 100 + interval / 2)
        let wait = slots.wait(at: 100 + interval / 2)
        let next = slots.take(at: 100 + interval)
        #expect(first)
        #expect(!early)
        #expect(abs(wait - interval / 2) < 1e-9)
        #expect(next)
    }

    @Test func manyLoopsShareOneSlotPerInterval() {
        var slots = AttemptSlots(interval: interval)
        let loops = 4
        var grants: [Double] = []
        for step in 0..<100 {
            let now = Double(step) * interval / Double(loops)
            for _ in 0..<loops where slots.take(at: now) { grants.append(now) }
        }
        #expect(zip(grants, grants.dropFirst()).allSatisfy { $1 - $0 >= interval - 1e-9 })
        #expect(grants.count >= 100 / (2 * loops))
    }

    @Test func idleSlotsNeedNoWait() {
        var slots = AttemptSlots(interval: interval)
        #expect(slots.wait(at: 0) == 0)
        _ = slots.take(at: 0)
        #expect(slots.wait(at: interval * 2) == 0)
    }
}
