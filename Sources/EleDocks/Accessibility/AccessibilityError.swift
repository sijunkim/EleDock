import ApplicationServices

/// 실패한 AX 호출의 AXError.
nonisolated enum AccessibilityError: Error {
    /// 앱이 응답하지 않는다.
    case cannotComplete
    /// 요소가 이미 사라졌다.
    case invalidUIElement
    case other(AXError)

    init(_ code: AXError) {
        switch code {
        case .cannotComplete: self = .cannotComplete
        case .invalidUIElement: self = .invalidUIElement
        default: self = .other(code)
        }
    }

    /// 응답 지연인지.
    var isDelay: Bool {
        if case .cannotComplete = self { true } else { false }
    }

    static func check(_ code: AXError) throws(AccessibilityError) {
        guard code == .success else { throw AccessibilityError(code) }
    }
}
