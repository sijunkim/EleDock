import ApplicationServices

/// AX 속성 값(AXValue)을 CoreGraphics 값으로 푼다.
extension CGPoint {
    init(axValue raw: CFTypeRef?) throws(AccessibilityError) {
        self = try decodeAXValue(raw, .cgPoint, initial: .zero)
    }
}

extension CGSize {
    init(axValue raw: CFTypeRef?) throws(AccessibilityError) {
        self = try decodeAXValue(raw, .cgSize, initial: .zero)
    }
}

private func decodeAXValue<T: BitwiseCopyable>(_ raw: CFTypeRef?, _ type: AXValueType, initial: T)
    throws(AccessibilityError) -> T
{
    guard let raw, CFGetTypeID(raw) == AXValueGetTypeID() else { throw .other(.failure) }
    var value = initial
    guard AXValueGetValue(raw as! AXValue, type, &value) else { throw .other(.failure) }
    return value
}
