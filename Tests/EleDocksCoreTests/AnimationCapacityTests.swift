import Foundation
import Testing

@testable import EleDocksCore

struct AnimationCapacityTests {
    @Test func concurrentOverlayLimitCoversLongestJobLifetimeAtRepeatInterval() {
        let longest = max(AnimationTiming.longestMinimizeLifetime, AnimationTiming.longestRestoreLifetime)
        let ticksDuringLongest = Int((longest / RepeatPolicy.interval).rounded(.up))
        #expect(AnimationTiming.maximumConcurrentOverlays == ticksDuringLongest + 1)
    }

    @Test func heldMinimizeJobsStayWithinLongestLifetime() {
        let jobs = simulateHeldMinimize(ticks: 200)
        let longest = jobs.map { $0.end - $0.admitted }.max() ?? 0
        #expect(jobs.count > AnimationTiming.maximumPendingCaptures)
        #expect(longest <= AnimationTiming.longestMinimizeLifetime + 1e-9)
        #expect(longest > AnimationTiming.longestMinimizeLifetime - RepeatPolicy.interval)
    }

    @Test func heldMinimizeNeverFallsBackForOverlayLimit() {
        #expect(simulateHeldMinimize(ticks: 200).allSatisfy { !$0.wasPlain })
    }

    @Test func restoreLifetimeExceedsAnimationAndPutBackWindow() {
        let restoreFloor = AnimationTiming.maximumDuration + AnimationTiming.putBackRetryWindow
        #expect(AnimationTiming.longestRestoreLifetime > restoreFloor)
    }

    // 최소화를 tick 마다 요청한다.
    private func simulateHeldMinimize(ticks: Int) -> [SimulatedJob] {
        var jobs: [SimulatedJob] = []
        for tick in 0..<ticks {
            let now = Double(tick) * RepeatPolicy.interval
            let alive = jobs.filter { !$0.wasPlain && $0.end > now }
            let admission = AnimationAdmission.minimize(
                activeJobs: alive.count, pendingCaptures: alive.filter { $0.captureEnd > now }.count,
                queuedMinimizes: alive.filter { $0.runEnd > now }.count)
            switch admission {
            case .animate:
                let previousEnd = jobs.last { !$0.wasPlain }?.runEnd ?? now
                jobs.append(SimulatedJob(admitted: now, runStart: max(now, previousEnd), wasPlain: false))
            case .plain:
                jobs.append(SimulatedJob(admitted: now, runStart: now, wasPlain: true))
            case .wait:
                break
            }
        }
        return jobs
    }
}

// 시뮬레이션의 최소화 작업 하나.
private struct SimulatedJob {
    let admitted: Double
    let runStart: Double
    let wasPlain: Bool

    var captureEnd: Double { runStart + AnimationTiming.captureTimeout }
    var runEnd: Double { runStart + AnimationTiming.longestMinimizeRun }
    var end: Double { runEnd + AnimationTiming.maximumDuration }
}
