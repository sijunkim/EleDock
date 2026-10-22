import ApplicationServices

/// AXUIElement 호출을 AccessibilityError 를 던지는 메서드로 감싼다.
extension AXUIElement {
    static func application(pid: pid_t) -> AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    static var systemWide: AXUIElement {
        AXUIElementCreateSystemWide()
    }

    func attribute(_ name: String) throws(AccessibilityError) -> CFTypeRef? {
        var value: CFTypeRef?
        try AccessibilityError.check(AXUIElementCopyAttributeValue(self, name as CFString, &value))
        return value
    }

    func setAttribute(_ name: String, _ value: CFTypeRef) throws(AccessibilityError) {
        try AccessibilityError.check(AXUIElementSetAttributeValue(self, name as CFString, value))
    }

    func perform(_ action: String) throws(AccessibilityError) {
        try AccessibilityError.check(AXUIElementPerformAction(self, action as CFString))
    }

    /// 여러 속성을 한 번에 읽는다.
    func attributes(_ names: [String]) throws(AccessibilityError) -> [AnyObject] {
        var values: CFArray?
        try AccessibilityError.check(AXUIElementCopyMultipleAttributeValues(self, names as CFArray, [], &values))
        return values as? [AnyObject] ?? []
    }

    /// 이 요소의 AX messaging timeout 을 건다.
    func setMessagingTimeout(_ seconds: Float) {
        AXUIElementSetMessagingTimeout(self, seconds)
    }

    /// `seconds` 동안만 응답을 기다리며 `body` 를 부른다.
    func withMessagingTimeout<T, E: Error>(_ seconds: Float?, _ body: () throws(E) -> T) throws(E) -> T {
        guard let seconds else { return try body() }
        setMessagingTimeout(seconds)
        defer { setMessagingTimeout(0) }
        return try body()
    }

    /// 요소를 가진 앱의 pid.
    var pid: pid_t {
        var pid: pid_t = 0
        AXUIElementGetPid(self, &pid)
        return pid
    }

    func setMinimized(_ minimized: Bool) throws(AccessibilityError) {
        let value: CFBoolean = minimized ? kCFBooleanTrue : kCFBooleanFalse
        try setAttribute(kAXMinimizedAttribute, value)
    }
}

/// AXObserver 생성과 알림 등록을 AccessibilityError 를 던지는 메서드로 감싼다.
extension AXObserver {
    static func make(pid: pid_t, callback: AXObserverCallback) throws(AccessibilityError) -> AXObserver {
        var observer: AXObserver?
        try AccessibilityError.check(AXObserverCreate(pid, callback, &observer))
        guard let observer else { throw .other(.failure) }
        return observer
    }

    func add(_ notification: String, for element: AXUIElement, refcon: UnsafeMutableRawPointer?)
        throws(AccessibilityError)
    {
        try AccessibilityError.check(AXObserverAddNotification(self, element, notification as CFString, refcon))
    }

    var runLoopSource: CFRunLoopSource {
        AXObserverGetRunLoopSource(self)
    }
}
