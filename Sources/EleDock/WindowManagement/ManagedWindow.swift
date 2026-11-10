import AppKit
import ApplicationServices
import EleDockCore

typealias WindowEntry = MinimizedStack<ManagedWindow>.Entry
typealias WindowConfirmations = Confirmations<WindowEntry, ManagedWindow, pid_t>

/// 최소화·복원 대상 창.
enum ManagedWindow: Equatable {
    /// 다른 앱의 창.
    case ax(AXUIElement)
    /// 이 앱의 창.
    case own(NSWindow)

    /// 포커스 AX 호출의 timeout.
    private static let focusTimeout: Float = 0.3

    // 앱의 창 목록을 화면 앞쪽 순서로 구한다.
    static func windows(of pid: pid_t) throws(AccessibilityError) -> [ManagedWindow] {
        guard pid != getpid() else {
            let front = (NSWindow.windowNumbers() ?? []).compactMap { NSApp.window(withWindowNumber: $0.intValue) }
            return (front + NSApp.windows.filter { !front.contains($0) }).map(own)
        }
        let app = AXUIElement.application(pid: pid)
        return try app.withMessagingTimeout(WindowTracker.callTimeout) { () throws(AccessibilityError) in
            try app.windows
        }.map(ax)
    }

    // 앱의 포커스 창.
    static func focused(of pid: pid_t) throws(AccessibilityError) -> ManagedWindow? {
        guard pid != getpid() else { return NSApp.keyWindow.map(own) }
        let app = AXUIElement.application(pid: pid)
        let value = try app.withMessagingTimeout(WindowTracker.callTimeout) { () throws(AccessibilityError) in
            try app.attribute(kAXFocusedWindowAttribute)
        }
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return .ax(value as! AXUIElement)
    }

    /// 오류를 구분해 읽은 최소화 여부.
    var minimizedAttribute: Bool {
        get throws(AccessibilityError) {
            switch self {
            case .ax(let window):
                try window.withMessagingTimeout(WindowTracker.callTimeout) { () throws(AccessibilityError) in
                    try window.minimizedAttribute
                }
            case .own(let window): window.isMiniaturized
            }
        }
    }

    var minimizedState: Bool? {
        try? minimizedAttribute
    }

    // 최소화되지 않은, 최소화할 수 있는 표준 창인지 본다.
    var isMinimizeCandidate: Bool {
        get throws(AccessibilityError) {
            switch self {
            case .ax(let window): try Self.isMinimizeCandidate(window)
            case .own(let window):
                window.isVisible && !window.isMiniaturized && window.styleMask.contains(.miniaturizable)
                    && window.accessibilitySubrole() == .standardWindow
            }
        }
    }

    private static func isMinimizeCandidate(_ window: AXUIElement) throws(AccessibilityError) -> Bool {
        try window.withMessagingTimeout(WindowTracker.callTimeout) { () throws(AccessibilityError) in
            do throws(AccessibilityError) {
                guard try !window.minimizedAttribute else { return false }
            } catch .cannotComplete {
                throw .cannotComplete
            } catch {}
            do throws(AccessibilityError) {
                return try window.attribute(kAXSubroleAttribute) as? String == kAXStandardWindowSubrole
            } catch .cannotComplete {
                throw .cannotComplete
            } catch {
                return false
            }
        }
    }

    func setMinimized(_ minimized: Bool) -> RepeatPolicy.Attempt {
        switch self {
        case .ax(let window):
            do {
                try window.withMessagingTimeout(WindowTracker.callTimeout) { () throws(AccessibilityError) in
                    try window.setMinimized(minimized)
                }
                return .success
            } catch .cannotComplete {
                return .busy
            } catch {
                return .failure
            }
        case .own(let window):
            if minimized { window.miniaturize(nil) } else { window.deminiaturize(nil) }
            return .success
        }
    }

    /// 창 제목.
    var title: String? {
        switch self {
        case .ax(let window): window.title
        case .own(let window): window.title.isEmpty ? nil : window.title
        }
    }

    // 창의 앱을 활성화하고 창을 앞으로 가져온다.
    func focus() {
        switch self {
        case .ax(let window):
            NSRunningApplication(processIdentifier: window.pid)?.activate(options: [])
            let app = AXUIElement.application(pid: window.pid)
            app.withMessagingTimeout(Self.focusTimeout) {
                try? app.setAttribute(kAXFrontmostAttribute, kCFBooleanTrue)
            }
            window.withMessagingTimeout(Self.focusTimeout) {
                try? window.perform(kAXRaiseAction)
                try? window.setAttribute(kAXMainAttribute, kCFBooleanTrue)
            }
        case .own(let window):
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }
}
