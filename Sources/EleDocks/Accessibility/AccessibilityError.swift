import ApplicationServices

/// 실패한 AX 호출의 AXError.
enum AccessibilityError: Error {
    /// 앱이 응답하지 않는다.
    case cannotComplete
    /// 요소가 이미 사라졌다.
    case invalidUIElement
    /// 앱이 속성·동작을 지원하지 않거나 구현하지 않았다고 답했다.
    case unsupported
    case other(AXError)

    init(_ code: AXError) {
        switch code {
        case .cannotComplete: self = .cannotComplete
        case .invalidUIElement: self = .invalidUIElement
        case .attributeUnsupported, .notImplemented: self = .unsupported
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
