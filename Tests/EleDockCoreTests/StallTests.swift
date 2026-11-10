import Foundation
import Testing

@testable import EleDockCore

struct StallTests {
    private let later = RepeatPolicy.stallDuration

    @Test func limitIsReachedOnlyByConsecutiveSameKey() {
        var stall = Stall<String>()
        var reached: [Bool] = []
        for (index, key) in ["a", "b", "b", "b"].enumerated() {
            reached.append(stall.recordStall(of: key, at: Double(index) * later))
        }
        stall.reset()
        reached.append(stall.recordStall(of: "a", at: 4 * later))
        #expect(reached == [false, false, true, false, false])
    }

    @Test func limitWaitsForStallDurationSinceFirstStall() {
        var stall = Stall<String>()
        var reached: [Bool] = []
        for now in [1, 1.5, 2.49, 2.5] { reached.append(stall.recordStall(of: "a", at: now)) }
        #expect(reached == [false, false, false, true])
    }

    @Test func newKeyRestartsStallDuration() {
        var stall = Stall<String>()
        var reached: [Bool] = []
        for (key, now) in [("a", 0), ("b", later), ("b", later + 1), ("b", 2 * later)] {
            reached.append(stall.recordStall(of: key, at: now))
        }
        #expect(reached == [false, false, false, true])
    }

    @Test func stallDurationOutlastsEarliestDelay() {
        #expect(RepeatPolicy.stallDuration >= 2 * SettleSchedule.earliestDelay)
    }
}
