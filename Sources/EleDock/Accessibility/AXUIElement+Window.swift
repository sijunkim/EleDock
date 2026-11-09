import ApplicationServices

/// 앱·창 요소의 창 관련 속성 조회.
extension AXUIElement {
    /// 앱의 창 목록.
    var windows: [AXUIElement] {
        get throws(AccessibilityError) {
            try attribute(kAXWindowsAttribute) as? [AXUIElement] ?? []
        }
    }

    var isMinimized: Bool {
        (try? minimizedAttribute) == true
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
