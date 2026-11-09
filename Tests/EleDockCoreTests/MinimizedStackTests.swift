import Testing

@testable import EleDockCore

struct MinimizedStackTests {
    private typealias Stack = MinimizedStack<String>

    private func make(_ items: [(Int32, String)]) -> Stack {
        var stack = Stack()
        for (pid, window) in items { stack.push(.init(pid: pid, window: window)) }
        return stack
    }

    @Test func popsInLastInFirstOutOrder() {
        var stack = make([(1, "a"), (2, "b"), (1, "c")])
        #expect(stack.last?.window == "c")
        #expect(stack.popLast()?.window == "c")
        #expect(stack.popLast()?.window == "b")
        #expect(stack.popLast()?.window == "a")
        #expect(stack.popLast() == nil)
    }

    @Test func pushingSameWindowMovesItToTop() {
        var stack = make([(1, "a"), (1, "b")])
        stack.push(.init(pid: 1, window: "a"))
        #expect(stack.recent(limit: 10).map(\.window) == ["a", "b"])
    }

    @Test func insertAtBottomIsRestoredLast() {
        var stack = make([(1, "a")])
        stack.insertAtBottom(.init(pid: 2, window: "old"))
        #expect(stack.recent(limit: 10).map(\.window) == ["a", "old"])
        #expect(stack.contains("old"))
    }

    @Test func insertAtBottomKeepsExistingPosition() {
        var stack = make([(1, "a"), (1, "b")])
        stack.insertAtBottom(.init(pid: 1, window: "b"))
        #expect(stack.recent(limit: 10).map(\.window) == ["b", "a"])
    }

    @Test func putBackRestoresTop() throws {
        var stack = make([(1, "a"), (1, "b")])
        let before = stack.recent(limit: 10).map(\.window)
        let popped = stack.popLast()
        let top = try #require(popped)
        stack.putBack(top)
        #expect(stack.recent(limit: 10).map(\.window) == before)
    }

    @Test func putBackSkipsWindowPushedAgain() throws {
        var stack = make([(1, "a"), (1, "b")])
        let popped = stack.popLast()
        let top = try #require(popped)
        stack.push(.init(pid: 1, window: "c"))
        stack.push(top)
        stack.putBack(top)
        #expect(stack.recent(limit: 10).map(\.window) == ["b", "c", "a"])
    }

    @Test func insertBelowPlacesUnderLowestStackedSuccessor() {
        var stack = make([(1, "x"), (1, "b"), (1, "d")])
        stack.insert(.init(pid: 1, window: "a"), below: ["c", "d", "b"])
        #expect(stack.recent(limit: 10).map(\.window) == ["d", "b", "a", "x"])
    }

    @Test func insertBelowWithoutStackedSuccessorGoesOnTop() {
        var stack = make([(1, "x"), (1, "a")])
        stack.insert(.init(pid: 1, window: "a"), below: ["c"])
        #expect(stack.recent(limit: 10).map(\.window) == ["a", "x"])
    }

    @Test func takeRemovesOnlyThatWindow() {
        var stack = make([(1, "a"), (1, "b"), (1, "c")])
        #expect(stack.take("b")?.window == "b")
        #expect(stack.take("b") == nil)
        #expect(stack.recent(limit: 10).map(\.window) == ["c", "a"])
    }

    @Test func removeByWindowAndPid() {
        var stack = make([(1, "a"), (2, "b"), (1, "c")])
        stack.remove("b")
        #expect(!stack.contains("b"))
        stack.removeAll(pid: 1)
        #expect(stack.recent(limit: 10).isEmpty)
    }

    @Test func recentReturnsNewestFirstUpToLimit() {
        let stack = make([(1, "a"), (1, "b"), (1, "c")])
        #expect(stack.recent(limit: 2).map(\.window) == ["c", "b"])
        #expect(stack.recent(limit: 0).isEmpty)
    }
}
