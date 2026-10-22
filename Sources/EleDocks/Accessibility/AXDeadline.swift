import ApplicationServices

/// 여러 AX 호출에 거는 전체 시간 예산.
struct AXDeadline {
    private let end: ContinuousClock.Instant

    init(seconds: Double) {
        end = .now + .seconds(seconds)
    }

    /// `body` 를 부른다.
    func run<T>(_ element: AXUIElement, _ body: () throws(AccessibilityError) -> T) throws(AccessibilityError) -> T {
        let remaining = end - .now
        guard remaining > .zero else { throw .cannotComplete }
        return try element.withMessagingTimeout(remaining.axTimeout, body)
    }
}

/// 여러 AX 호출이 메인 스레드를 막는 누적 시간 상한.
struct AXBlockingBudget {
    private var remaining: Duration

    init(seconds: Double) {
        remaining = .seconds(seconds)
    }

    var isExhausted: Bool { remaining <= .zero }

    /// `body` 를 부른다.
    mutating func run<T>(_ element: AXUIElement, timeout: Float, _ body: () throws(AccessibilityError) -> T)
        throws(AccessibilityError) -> T
    {
        guard remaining > .zero else { throw .cannotComplete }
        let start = ContinuousClock.now
        defer { remaining -= ContinuousClock.now - start }
        return try element.withMessagingTimeout(min(timeout, remaining.axTimeout), body)
    }
}

extension Duration {
    /// AX timeout 하한.
    private static let minimumAXTimeout: Float = 0.001

    /// AX messaging timeout 으로 쓸 초.
    fileprivate var axTimeout: Float {
        let (seconds, attoseconds) = components
        return max(Float(Double(seconds) + Double(attoseconds) * 1e-18), Self.minimumAXTimeout)
    }
}
