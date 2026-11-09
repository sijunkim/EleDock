import Testing

@testable import EleDockCore

struct MinimizeOrderTests {
    @Test(arguments: [(true, false, true), (true, true, false), (false, false, false), (false, true, false)])
    func candidateMustBeRegularAndNotExcluded(isRegular: Bool, isExcluded: Bool, expected: Bool) {
        #expect(MinimizeOrder.isCandidate(isRegular: isRegular, isExcluded: isExcluded) == expected)
    }

    @Test func keepsZOrderWithoutDuplicates() {
        let pids = MinimizeOrder.pids(zOrder: [3, 1, 3, 2, 1], frontmost: nil) { _ in true }
        #expect(pids == [3, 1, 2])
    }

    @Test func filtersNonCandidatesAndAsksOncePerPid() {
        var asked: [Int32] = []
        let pids = MinimizeOrder.pids(zOrder: [1, 2, 1, 3], frontmost: nil) {
            asked.append($0)
            return $0 != 2
        }
        #expect(pids == [1, 3])
        #expect(asked == [1, 2, 3])
    }

    @Test func movesFrontmostCandidateToFront() {
        #expect(MinimizeOrder.pids(zOrder: [1, 2, 3], frontmost: 3) { _ in true } == [3, 1, 2])
    }

    @Test func insertsFrontmostMissingFromZOrder() {
        #expect(MinimizeOrder.pids(zOrder: [1, 2], frontmost: 9) { _ in true } == [9, 1, 2])
    }

    @Test func ignoresFrontmostThatIsNotCandidate() {
        #expect(MinimizeOrder.pids(zOrder: [1, 2, 3], frontmost: 3) { $0 != 3 } == [1, 2])
    }

    @Test func collectsWindowsInPidOrder() {
        let windows = MinimizeOrder.windows(pids: [3, 1], frontmost: 3) { [$0 * 10, $0 * 10 + 1] }
        #expect(windows == [30, 31, 10, 11])
    }

    @Test func busyFrontmostStopsCollecting() {
        var asked: [Int32] = []
        let windows = MinimizeOrder.windows(pids: [3, 1], frontmost: 3) { pid -> [Int32]? in
            asked.append(pid)
            return pid == 3 ? nil : [pid]
        }
        #expect(windows == nil)
        #expect(asked == [3])
    }

    @Test func busyBackgroundAppIsSkipped() {
        let windows = MinimizeOrder.windows(pids: [3, 1, 2], frontmost: 3) { $0 == 1 ? nil : [$0] }
        #expect(windows == [3, 2])
    }

    @Test func busyAppWithoutFrontmostIsSkipped() {
        let windows = MinimizeOrder.windows(pids: [1, 2], frontmost: nil) { $0 == 1 ? nil : [$0] }
        #expect(windows == [2])
    }
}
