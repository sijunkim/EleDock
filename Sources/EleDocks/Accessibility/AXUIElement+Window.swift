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

    /// `deadline` 안에서 읽은 창 제목.
    func title(before deadline: AXDeadline) -> String? {
        let title = try? deadline.run(self) { () throws(AccessibilityError) in try attribute(kAXTitleAttribute) }
        return (title as? String).flatMap { $0.isEmpty ? nil : $0 }
    }
}

/// 창 frame·상태 조회와 frame 변경.
extension AXUIElement {
    /// 위치·크기를 읽은 frame.
    var frame: CGRect {
        get throws(AccessibilityError) {
            CGRect(
                origin: try CGPoint(axValue: attribute(kAXPositionAttribute)),
                size: try CGSize(axValue: attribute(kAXSizeAttribute)))
        }
    }

    /// `deadline` 안에서 위치·크기를 읽는다.
    func frame(before deadline: AXDeadline) throws(AccessibilityError) -> CGRect {
        let position = try deadline.run(self) { () throws(AccessibilityError) in try attribute(kAXPositionAttribute) }
        let size = try deadline.run(self) { () throws(AccessibilityError) in try attribute(kAXSizeAttribute) }
        return CGRect(origin: try CGPoint(axValue: position), size: try CGSize(axValue: size))
    }

    /// `deadline` 안에서 frame 을 바꾼다.
    func setFrame(_ frame: CGRect, before deadline: AXDeadline, sizeFirst: Bool = false) throws(AccessibilityError) {
        var origin = frame.origin
        var size = frame.size
        guard let position = AXValueCreate(.cgPoint, &origin), let sizeValue = AXValueCreate(.cgSize, &size) else {
            throw .other(.failure)
        }
        let order =
            sizeFirst
            ? [(kAXSizeAttribute, sizeValue), (kAXPositionAttribute, position)]
            : [(kAXPositionAttribute, position), (kAXSizeAttribute, sizeValue), (kAXPositionAttribute, position)]
        for (name, value) in order {
            try deadline.run(self) { () throws(AccessibilityError) in try setAttribute(name, value) }
        }
    }

    /// 전체 화면 창인지.
    var isFullScreen: Bool {
        get throws(AccessibilityError) {
            do {
                return (try attribute("AXFullScreen") as? Bool) == true
            } catch .other, .unsupported {
                return false
            }
        }
    }

    /// `deadline` 안에서 자식 중 AXSheet 가 있는지 본다.
    func hasSheet(before deadline: AXDeadline) throws(AccessibilityError) -> Bool {
        try hasSheet(
            children: { () throws(AccessibilityError) in
                try deadline.run(self) { () throws(AccessibilityError) in try attribute(kAXChildrenAttribute) }
            },
            role: { (child) throws(AccessibilityError) -> CFTypeRef? in
                do throws(AccessibilityError) {
                    return try deadline.run(child) { () throws(AccessibilityError) in
                        try child.attribute(kAXRoleAttribute)
                    }
                } catch .cannotComplete {
                    throw .cannotComplete
                } catch {
                    return nil
                }
            })
    }

    // 읽은 자식 목록과 역할로 AXSheet 가 있는지 본다.
    private func hasSheet(
        children: () throws(AccessibilityError) -> CFTypeRef?,
        role: (AXUIElement) throws(AccessibilityError) -> CFTypeRef?
    ) throws(AccessibilityError) -> Bool {
        let elements: [AXUIElement]
        do {
            elements = try children() as? [AXUIElement] ?? []
        } catch .other, .unsupported {
            return false
        }
        for child in elements where try role(child) as? String == kAXSheetRole {
            return true
        }
        return false
    }
}
