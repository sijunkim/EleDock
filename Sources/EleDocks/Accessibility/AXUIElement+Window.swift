import ApplicationServices

/// 앱·창 요소의 창 관련 속성 조회.
extension AXUIElement {
    /// 앱의 창 목록.
    var windows: [AXUIElement] {
        get throws(AccessibilityError) {
            try attribute(kAXWindowsAttribute) as? [AXUIElement] ?? []
        }
    }

    var subrole: String? {
        (try? attribute(kAXSubroleAttribute)) as? String
    }

    var focusedWindow: AXUIElement? {
        guard let value = try? attribute(kAXFocusedWindowAttribute), CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }

    var isMinimized: Bool {
        minimizedState == true
    }

    /// 창의 최소화 여부.
    var minimizedState: Bool? {
        try? minimizedAttribute
    }

    /// 오류를 구분해 읽은 창의 최소화 여부.
    var minimizedAttribute: Bool {
        get throws(AccessibilityError) {
            do {
                return (try attribute(kAXMinimizedAttribute) as? Bool) == true
            } catch .invalidUIElement {
                return false
            }
        }
    }

    /// 창 제목.
    var title: String? {
        let title = try? withMessagingTimeout(WindowTracker.callTimeout) { () throws(AccessibilityError) in
            try attribute(kAXTitleAttribute)
        }
        return (title as? String).flatMap { $0.isEmpty ? nil : $0 }
    }
}
