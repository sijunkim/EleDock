import Testing

@testable import EleDocksCore

struct DeferredRegistrationsTests {
    private typealias Deferred = DeferredRegistrations<Int, Int>

    private func makeDeferred(_ elements: [Int]) -> Deferred {
        var deferred = Deferred { $0 / 10 }
        for element in elements { deferred.add(element) }
        return deferred
    }

    @Test func addIgnoresDuplicates() {
        var deferred = makeDeferred([1, 2])
        deferred.add(1)
        #expect(deferred.pending == [1, 2])
    }

    @Test func removesByElementAndByCondition() {
        var deferred = makeDeferred([1, 2, 3, 4])
        deferred.remove(2)
        #expect(deferred.pending == [1, 3, 4])
        deferred.removeAll { $0 > 3 }
        #expect(deferred.pending == [1, 3])
    }

    @Test func flushKeepsBusyAndReturnsGone() {
        var deferred = makeDeferred([1, 12, 23, 34])
        let outcomes: [Int: RegistrationOutcome] = [1: .registered, 12: .busy, 23: .gone, 34: .failed]
        var attempted: [Int] = []
        let gone = deferred.flush { element in
            attempted.append(element)
            return outcomes[element]!
        }
        #expect(attempted == [1, 12, 23, 34])
        #expect(gone == [23])
        #expect(deferred.pending == [12])
    }

    @Test func flushSkipsRestOfBusyGroup() {
        var deferred = makeDeferred([10, 20, 11, 21, 12])
        var attempted: [Int] = []
        let gone = deferred.flush { element in
            attempted.append(element)
            return element / 10 == 1 ? .busy : .registered
        }
        #expect(attempted == [10, 20, 21])
        #expect(gone.isEmpty)
        #expect(deferred.pending == [10, 11, 12])
    }

    @Test func dropsAfterAttemptLimit() {
        var deferred = makeDeferred([10, 11])
        for _ in 1..<Deferred.attemptLimit {
            _ = deferred.flush { _ in .busy }
            #expect(deferred.pending == [10, 11])
        }
        let gone = deferred.flush { _ in .busy }
        #expect(gone.isEmpty)
        #expect(deferred.isEmpty)
    }

    @Test func addedLaterGetsFullAttempts() {
        var deferred = makeDeferred([10])
        for _ in 1..<Deferred.attemptLimit { _ = deferred.flush { _ in .busy } }
        deferred.add(11)
        _ = deferred.flush { _ in .busy }
        #expect(deferred.pending == [11])
    }

    @Test func flushEmptiesWhenAllRegistered() {
        var deferred = makeDeferred([1])
        let gone = deferred.flush { _ in .registered }
        #expect(gone.isEmpty)
        #expect(deferred.isEmpty)
    }
}
