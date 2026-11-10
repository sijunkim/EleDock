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

}

struct MinimizeQueueTests {
    private func drain(_ queue: inout MinimizeQueue<Int32>) -> [Int32] {
        var sent: [Int32] = []
        while let window = queue.peek() {
            sent.append(window)
            queue.drop()
        }
        return sent
    }

    @Test func givesWindowsInPidOrder() {
        var queue = MinimizeQueue(pids: [3, 1]) { [$0 * 10, $0 * 10 + 1] }
        #expect(drain(&queue) == [30, 31, 10, 11])
    }

    @Test func queriesAppOnlyWhenReachedAndOnce() {
        var asked: [Int32] = []
        var queue = MinimizeQueue(pids: [3, 1]) { pid -> [Int32]? in
            asked.append(pid)
            return [pid * 10, pid * 10 + 1]
        }
        #expect(queue.peek() == 30)
        #expect(asked == [3])
        queue.drop()
        #expect(queue.peek() == 31)
        #expect(asked == [3])
        queue.drop()
        #expect(queue.peek() == 10)
        #expect(asked == [3, 1])
    }

    @Test func appWithoutWindowsIsPassedInSamePeek() {
        var queue = MinimizeQueue(pids: [3, 1, 2]) { $0 == 1 ? [] : [$0] }
        #expect(drain(&queue) == [3, 2])
    }

    @Test func busyFrontAppIsQueriedAgainOnNextPeek() {
        var busy = true
        var asked: [Int32] = []
        var queue = MinimizeQueue(pids: [3, 1]) { pid -> [Int32]? in
            asked.append(pid)
            return pid == 3 && busy ? nil : [pid]
        }
        #expect(queue.peek() == nil)
        busy = false
        #expect(drain(&queue) == [3, 1])
        #expect(asked == [3, 3, 1])
    }

    @Test func busyBackAppIsSkipped() {
        var queue = MinimizeQueue(pids: [3, 1, 2]) { pid -> [Int32]? in
            pid == 1 ? nil : [pid]
        }
        #expect(drain(&queue) == [3, 2])
    }

    @Test func windowsAreFixedWhenAppIsQueried() {
        var windows: [Int32] = [30, 31]
        var queue = MinimizeQueue(pids: [3]) { _ in windows }
        #expect(queue.peek() == 30)
        windows = [32]
        queue.drop()
        #expect(drain(&queue) == [31])
    }

    @Test func upcomingQueriesUntilNextAppWithWindows() {
        var asked: [Int32] = []
        var queue = MinimizeQueue(pids: [3, 1, 4, 2, 5]) { pid -> [Int32]? in
            asked.append(pid)
            switch pid {
            case 1: return nil
            case 4: return []
            default: return [pid * 10, pid * 10 + 1]
            }
        }
        #expect(queue.peek() == 30)
        queue.drop()
        #expect(queue.upcoming() == [31, 20, 21])
        #expect(asked == [3, 1, 4, 2])
    }
}
